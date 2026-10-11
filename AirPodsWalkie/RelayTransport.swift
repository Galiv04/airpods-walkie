import Foundation

/// Trasporto via internet: WebSocket verso un relay (relay/ nella repo) che inoltra i byte agli altri
/// partecipanti della stanza. Payload cifrato end-to-end (RoomCrypto).
final class RelayTransport: NSObject {
    private let url: URL
    private let crypto: RoomCrypto
    private let lock = NSLock()
    private var task: URLSessionWebSocketTask?
    private var session: URLSession!
    private var stopped = true
    private var peers = 0
    private var isOpen = false
    private var attempts = 0
    private var pingTimer: Timer?

    var onAudio: ((Data) -> Void)?
    /// Main thread: true se l'altro è presente nella stanza sul relay.
    var onState: ((Bool) -> Void)?
    var onRemoteTalking: ((Bool) -> Void)?
    /// Main thread: nome dell'altro.
    var onHello: ((String) -> Void)?

    /// `base` può essere https://x, wss://x o x.workers.dev. Con `echo` il relay rimanda indietro
    /// i nostri stessi pacchetti (test con un solo telefono).
    init?(base: String, room: String, echo: Bool = false) {
        var s = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "wss://" + s }
        s = s.replacingOccurrences(of: "https://", with: "wss://").replacingOccurrences(of: "http://", with: "ws://")
        while s.hasSuffix("/") { s.removeLast() }
        crypto = RoomCrypto(room: room)
        guard let u = URL(string: s + (echo ? "/echo/" : "/room/") + crypto.roomId) else { return nil }
        url = u
        super.init()
        session = URLSession(configuration: .default)
    }

    var isConnected: Bool { lock.lock(); defer { lock.unlock() }; return isOpen && peers >= 2 }

    func start() {
        lock.lock(); stopped = false; lock.unlock()
        connect()
        DispatchQueue.main.async {
            self.pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
                self?.task?.sendPing { _ in }
            }
        }
    }

    func stop() {
        lock.lock(); stopped = true; isOpen = false; peers = 0; lock.unlock()
        task?.cancel(with: .goingAway, reason: nil); task = nil
        DispatchQueue.main.async { self.pingTimer?.invalidate(); self.pingTimer = nil }
    }

    func send(_ msg: WireMessage) {
        guard isConnected, let sealed = crypto.seal(msg.encoded) else { return }
        task?.send(.data(sealed)) { _ in }
    }

    private func connect() {
        let t = session.webSocketTask(with: url)
        task = t
        t.resume()
        receive(t)
    }

    private func receive(_ t: URLSessionWebSocketTask) {
        t.receive { [weak self] result in
            guard let self, t === self.task else { return }
            switch result {
            case .failure: self.reconnect()
            case .success(let m):
                self.lock.lock(); self.isOpen = true; self.attempts = 0; self.lock.unlock()
                switch m {
                case .data(let d): self.handle(d)
                case .string(let s): self.handleControl(s)
                @unknown default: break
                }
                self.receive(t)
            }
        }
    }

    private func handleControl(_ s: String) {
        guard let d = s.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
              let n = o["peers"] as? Int else { return }
        lock.lock(); peers = n; lock.unlock()
        DispatchQueue.main.async { self.onState?(n >= 2) }
        if n < 2 { DispatchQueue.main.async { self.onRemoteTalking?(false) } }
    }

    private func handle(_ d: Data) {
        guard let plain = crypto.open(d), let msg = WireMessage.decode(plain) else { return }
        switch msg {
        case .audio(let pcm): onAudio?(pcm)
        case .talking(let on): DispatchQueue.main.async { self.onRemoteTalking?(on) }
        case .hello(let name): DispatchQueue.main.async { self.onHello?(name) }
        }
    }

    private func reconnect() {
        lock.lock()
        isOpen = false; peers = 0
        let wait = min(pow(2, Double(attempts)), 15)
        attempts += 1
        let stop = stopped
        lock.unlock()
        DispatchQueue.main.async { self.onState?(false); self.onRemoteTalking?(false) }
        guard !stop else { return }
        DispatchQueue.global().asyncAfter(deadline: .now() + wait) { [weak self] in
            guard let self else { return }
            self.lock.lock(); let s = self.stopped; self.lock.unlock()
            if !s { self.connect() }
        }
    }
}
