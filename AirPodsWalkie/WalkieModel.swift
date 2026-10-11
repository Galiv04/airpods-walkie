import AVFoundation
import MediaPlayer
import SwiftUI

enum TalkMode: String, CaseIterable, Identifiable {
    case pushToTalk = "Premi"
    case latch = "Tocca"
    case vox = "Voce"
    var id: String { rawValue }
}

enum LinkMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case nearby = "Vicino"
    case internet = "Internet"
    var id: String { rawValue }
}

/// Collega UI, audio e trasporti (vicino via Multipeer + internet via relay).
@MainActor
final class WalkieModel: ObservableObject {
    @Published var room: String { didSet { UserDefaults.standard.set(room, forKey: "room") } }
    @Published var mode: TalkMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode"); setTalking(false) } }
    @Published var linkMode: LinkMode { didSet { UserDefaults.standard.set(linkMode.rawValue, forKey: "link") } }
    @Published var relayURL: String { didSet { UserDefaults.standard.set(relayURL, forKey: "relayURL") } }
    @Published var highQuality: Bool { didSet { UserDefaults.standard.set(highQuality, forKey: "hq") } }
    @Published var voxThreshold: Double { didSet { UserDefaults.standard.set(voxThreshold, forKey: "vox") } }
    @Published var isRunning = false
    @Published var nearbyName: String?
    @Published var nearbyConnecting = false
    @Published var relayPeer = false
    @Published var talking = false
    @Published var remoteTalking = false
    @Published var level: Float = 0
    @Published var outputName = "—"
    @Published var error: String?

    private let audio = AudioEngine()
    private var nearby: PeerTransport?
    private var relay: RelayTransport?
    private var voxHoldUntil = Date.distantPast
    // Letti dal thread audio.
    nonisolated(unsafe) private var gateOpen = false

    /// URL relay di default, iniettato in build (variabile RELAY_URL della CI).
    static var defaultRelayURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "RelayURL") as? String).flatMap { $0.hasPrefix("$(") ? nil : $0 } ?? ""
    }

    init() {
        let d = UserDefaults.standard
        room = d.string(forKey: "room") ?? "moto"
        mode = TalkMode(rawValue: d.string(forKey: "mode") ?? "") ?? .pushToTalk
        linkMode = LinkMode(rawValue: d.string(forKey: "link") ?? "") ?? .auto
        relayURL = d.string(forKey: "relayURL") ?? Self.defaultRelayURL
        highQuality = d.bool(forKey: "hq")
        voxThreshold = d.object(forKey: "vox") as? Double ?? 0.1
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.outputName = AudioEngine.currentOutputName }
        }
        setupRemoteCommands()
    }

    var linked: Bool { nearbyName != nil || relayPeer }

    var statusText: String {
        if !isRunning { return "Spento" }
        if let n = nearbyName { return "Vicino: \(n)" }
        if relayPeer { return "Collegato via internet" }
        return nearbyConnecting ? "Connessione…" : "Cerco l'altro iPhone…"
    }

    func startStop() { isRunning ? stop() : start() }

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { self.error = "Permesso microfono negato (Impostazioni › Roger)."; return }
                self.begin()
            }
        }
    }

    private func begin() {
        error = nil
        let roomCode = room.trimmingCharacters(in: .whitespaces).lowercased()
        let audio = self.audio

        if linkMode != .internet {
            let t = PeerTransport(room: roomCode)
            t.onAudio = { data in audio.play(data) }
            t.onState = { [weak self] name, connecting in self?.nearbyName = name; self?.nearbyConnecting = connecting }
            t.onRemoteTalking = { [weak self] on in self?.remoteTalking = on }
            nearby = t
        }
        if linkMode != .nearby {
            if let r = RelayTransport(base: relayURL, room: roomCode) {
                r.onAudio = { data in audio.play(data) }
                r.onState = { [weak self] present in self?.relayPeer = present }
                r.onRemoteTalking = { [weak self] on in self?.remoteTalking = on }
                relay = r
            } else if linkMode == .internet {
                error = "Inserisci l'indirizzo del relay (Impostazioni)."; return
            }
        }

        let n = nearby, r = relay, mode = linkMode
        audio.onCapturedPacket = { [weak self] data in
            guard let self, self.gateOpen else { return }
            Self.route(.audio(data), nearby: n, relay: r, mode: mode)
        }
        audio.onLevel = { [weak self] lvl in
            guard let self else { return }
            Task { @MainActor in self.handleLevel(lvl) }
        }
        do { try audio.start(highQuality: highQuality) } catch {
            self.error = "Audio: \(error.localizedDescription)"; return
        }
        nearby?.start(); relay?.start()
        isRunning = true
        outputName = AudioEngine.currentOutputName
        UIApplication.shared.isIdleTimerDisabled = true
        updateNowPlaying()
    }

    /// Audio: un solo canale alla volta (vicino se collegato, altrimenti internet) per non duplicare.
    private nonisolated static func route(_ msg: WireMessage, nearby: PeerTransport?, relay: RelayTransport?, mode: LinkMode) {
        if let n = nearby, n.isConnected { n.send(msg) }
        else if let r = relay, r.isConnected { r.send(msg) }
    }

    func stop() {
        setTalking(false)
        nearby?.stop(); nearby = nil
        relay?.stop(); relay = nil
        audio.stop()
        isRunning = false; nearbyName = nil; nearbyConnecting = false; relayPeer = false
        remoteTalking = false; level = 0
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: Talk gating

    func setTalking(_ on: Bool) {
        guard talking != on else { return }
        talking = on
        gateOpen = on
        let msg = WireMessage.talking(on)
        // Lo stato "parla" è solo informativo: manda su tutti i canali attivi.
        if let n = nearby, n.isConnected { n.send(msg) }
        if let r = relay, r.isConnected { r.send(msg) }
    }

    func pttChanged(pressed: Bool) {
        guard isRunning else { return }
        switch mode {
        case .pushToTalk: setTalking(pressed)
        case .latch: if pressed { setTalking(!talking) }
        case .vox: break
        }
    }

    private func handleLevel(_ lvl: Float) {
        level = lvl
        guard isRunning, mode == .vox else { return }
        if lvl > Float(voxThreshold) { voxHoldUntil = Date().addingTimeInterval(0.8) }
        setTalking(Date() < voxHoldUntil)
    }

    // MARK: Tasto fisico AirPods (stem/play-pause) e lock screen

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        let toggle: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.setTalking(!self.talking)
            }
            return .success
        }
        c.togglePlayPauseCommand.addTarget(handler: toggle)
        c.playCommand.addTarget(handler: toggle)
        c.pauseCommand.addTarget(handler: toggle)
    }

    private func updateNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Walkie attivo",
            MPMediaItemPropertyArtist: "Premi play/pausa per parlare",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

}
