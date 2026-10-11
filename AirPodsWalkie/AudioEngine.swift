import AVFoundation
import Foundation

/// Cattura il microfono (AirPods via HFP), lo converte in PCM Int16 16 kHz mono e riproduce
/// l'audio ricevuto. Usa `.voiceChat` + voice processing per cancellazione rumore/eco.
final class AudioEngine {
    /// 24 kHz: sfrutta il super-wideband quando la route lo permette, in HFP classico è un semplice upsample.
    static let wireRate: Double = 24_000

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let wireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: wireRate, channels: 1, interleaved: true)!
    private let playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: wireRate, channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var running = false
    private var observers: [NSObjectProtocol] = []

    private let pendingLock = NSLock()
    private var pendingFrames = 0
    private let maxPendingFrames = 7_200   // ~300 ms: oltre, scarta per non accumulare latenza
    private let prebufferFrames = 1_920    // ~80 ms di pre-roll anti-jitter all'inizio di ogni frase
    private var primed = false
    private var held: [AVAudioPCMBuffer] = []
    private var heldFrames = 0
    private var lastPacket = Date.distantPast

    /// Pacchetto PCM Int16 pronto da inviare (thread audio).
    var onCapturedPacket: ((Data) -> Void)?
    /// Livello microfono 0...1 (thread audio).
    var onLevel: ((Float) -> Void)?

    /// - Parameter highQuality: (sperimentale, iOS 26+) registrazione AirPods "alta qualità" senza voice processing.
    ///   Di default: `.voiceChat` con voice processing = voce pulita e link Bluetooth più robusto.
    func start(highQuality: Bool = false) throws {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        var useVoiceProcessing = true
        var configured = false
        #if compiler(>=6.2)
        if highQuality, #available(iOS 26.0, *) {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.allowBluetoothHFP, .bluetoothHighQualityRecording, .defaultToSpeaker])
            useVoiceProcessing = false
            configured = true
        }
        #endif
        if !configured {
            try session.setCategory(.playAndRecord, mode: .voiceChat,
                                    options: [.allowBluetooth, .defaultToSpeaker])
        }
        try session.setActive(true)

        // Voice processing = AEC + noise suppression + AGC (deve precedere l'avvio del motore).
        if useVoiceProcessing { try? engine.inputNode.setVoiceProcessingEnabled(true) }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playFormat)

        installTap()
        engine.prepare()
        try engine.start()
        player.play()
        running = true
        observe()
    }

    private func installTap() {
        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: wireFormat)
        input.installTap(onBus: 0, bufferSize: 512, format: inFormat) { [weak self] buf, _ in
            self?.handleCaptured(buf)
        }
    }

    /// Il motore si ferma da solo quando cambia la route (AirPods collegati/scollegati, modalità microfono,
    /// chiamate, Siri): ripartiamo ricreando tap e convertitore.
    private func observe() {
        let nc = NotificationCenter.default
        observers.append(nc.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.recover()
        })
        observers.append(nc.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] n in
            let raw = n.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt ?? 0
            if AVAudioSession.InterruptionType(rawValue: raw) == .ended { self?.recover() }
        })
        observers.append(nc.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recover()
        })
    }

    private func recover() {
        guard running else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        pendingLock.lock(); pendingFrames = 0; primed = false; held = []; heldFrames = 0; pendingLock.unlock()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            installTap()
            engine.prepare()
            try engine.start()
            player.play()
        } catch {
            // Riprova una volta dopo un attimo (la route può essere ancora in transizione).
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.running, !self.engine.isRunning else { return }
                self.engine.inputNode.removeTap(onBus: 0)
                self.installTap()
                try? self.engine.start()
                self.player.play()
            }
        }
    }

    func stop() {
        guard running else { return }
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
        engine.inputNode.removeTap(onBus: 0)
        player.stop()
        engine.stop()
        engine.detach(player)
        running = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func handleCaptured(_ buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        let ratio = Self.wireRate / buffer.format.sampleRate
        let cap = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let out = AVAudioPCMBuffer(pcmFormat: wireFormat, frameCapacity: cap) else { return }
        var supplied = false
        var err: NSError?
        converter.convert(to: out, error: &err) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        guard err == nil, out.frameLength > 0, let ch = out.int16ChannelData else { return }
        let n = Int(out.frameLength)
        let samples = UnsafeBufferPointer(start: ch[0], count: n)

        var sum: Float = 0
        for s in samples { let f = Float(s) / 32768; sum += f * f }
        onLevel?(min(1, (sum / Float(n)).squareRoot() * 4))

        onCapturedPacket?(Data(buffer: samples))
    }

    /// Riproduce un pacchetto PCM Int16 ricevuto (con pre-roll anti-jitter).
    func play(_ data: Data) {
        guard running else { return }
        let n = data.count / 2
        guard n > 0, let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(n)) else { return }
        buf.frameLength = AVAudioFrameCount(n)
        let dst = buf.floatChannelData![0]
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<n { dst[i] = Float(Int16(littleEndian: src[i])) / 32768 }
        }

        pendingLock.lock()
        defer { pendingLock.unlock() }
        let now = Date()
        if now.timeIntervalSince(lastPacket) > 0.2 { primed = false; held = []; heldFrames = 0 }
        lastPacket = now
        if !primed {
            held.append(buf); heldFrames += n
            guard heldFrames >= prebufferFrames else { return }
            primed = true
            let toPlay = held; held = []; heldFrames = 0
            toPlay.forEach(schedule)
            return
        }
        schedule(buf)
    }

    /// Chiamare con `pendingLock` acquisito.
    private func schedule(_ buf: AVAudioPCMBuffer) {
        let n = Int(buf.frameLength)
        if pendingFrames + n > maxPendingFrames { return }
        pendingFrames += n
        player.scheduleBuffer(buf) { [weak self] in
            DispatchQueue.global().async {
                guard let self else { return }
                self.pendingLock.lock(); self.pendingFrames = max(0, self.pendingFrames - n); self.pendingLock.unlock()
            }
        }
    }

    // MARK: Suoni di servizio (generati, non trasmessi)

    enum Cue { case talkStart, talkEnd, roger, linked }

    /// Beep locali: inizio/fine trasmissione, "roger" quando l'altro chiude, collegamento riuscito.
    func playCue(_ cue: Cue) {
        guard running else { return }
        let tones: [(freq: Double, dur: Double)]
        switch cue {
        case .talkStart: tones = [(880, 0.05), (1320, 0.07)]
        case .talkEnd: tones = [(1320, 0.05), (880, 0.07)]
        case .roger: tones = [(1250, 0.06), (0, 0.035), (1250, 0.06)]
        case .linked: tones = [(660, 0.07), (990, 0.07), (1320, 0.1)]
        }
        let rate = Self.wireRate
        let total = tones.reduce(0) { $0 + Int($1.dur * rate) }
        guard let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(total)) else { return }
        buf.frameLength = AVAudioFrameCount(total)
        let out = buf.floatChannelData![0]
        var i = 0
        let fade = Int(0.005 * rate)
        for t in tones {
            let n = Int(t.dur * rate)
            for k in 0..<n {
                let env = Float(min(1, Double(min(k, n - 1 - k)) / Double(fade)))
                out[i] = t.freq == 0 ? 0 : Float(sin(2 * .pi * t.freq * Double(k) / rate)) * 0.18 * env
                i += 1
            }
        }
        player.scheduleBuffer(buf, completionHandler: nil)
    }

    /// Nome del dispositivo di uscita attuale (es. "AirPods di Gaetano").
    static var currentOutputName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "—"
    }
}
