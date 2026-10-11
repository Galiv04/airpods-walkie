import AVFoundation
import MediaPlayer
import SwiftUI

enum LinkMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case nearby = "Vicino"
    case internet = "Internet"
    var id: String { rawValue }
}

/// Codice coppia: 10 caratteri casuali (alfabeto senza caratteri ambigui) = ~50 bit.
/// È l'identità della coppia sia per il link vicino (hash nel discovery) sia per il relay, ed è la chiave E2E.
enum PairCode {
    static let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    static func generate() -> String {
        var g = SystemRandomNumberGenerator()
        return String((0..<10).map { _ in alphabet.randomElement(using: &g)! })
    }

    /// Accetta input con trattini/spazi/minuscole, un link roger://pair?code=… o l'intero messaggio condiviso.
    /// nil se non valido.
    static func normalize(_ input: String) -> String? {
        var s = input
        if let r = s.range(of: "code=") {
            s = String(s[r.upperBound...].prefix { $0.isLetter || $0.isNumber })
        } else if let r = s.range(of: "[A-Za-z0-9]{5}-[A-Za-z0-9]{5}", options: .regularExpression) {
            s = String(s[r])
        }
        let cleaned = s.uppercased().filter { alphabet.contains($0) }
        return cleaned.count == 10 ? cleaned : nil
    }

    static func pretty(_ c: String) -> String {
        c.count == 10 ? "\(c.prefix(5))-\(c.suffix(5))" : c
    }
}

/// Collega UI, audio e trasporti (vicino via Multipeer + internet via relay).
@MainActor
final class WalkieModel: ObservableObject {
    /// Istanza dell'app, per Siri/Comandi rapidi (Intents.swift).
    static weak var shared: WalkieModel?

    @Published var pairCode: String { didSet { UserDefaults.standard.set(pairCode, forKey: "pairCode") } }
    @Published var myName: String { didSet { UserDefaults.standard.set(myName, forKey: "myName") } }
    @Published var partnerName: String { didSet { UserDefaults.standard.set(partnerName, forKey: "partnerName") } }
    @Published var linkMode: LinkMode { didSet { UserDefaults.standard.set(linkMode.rawValue, forKey: "link") } }
    @Published var relayURL: String { didSet { UserDefaults.standard.set(relayURL, forKey: "relayURL") } }
    @Published var highQuality: Bool { didSet { UserDefaults.standard.set(highQuality, forKey: "hq") } }
    /// Mani libere: trasmette quando rileva la voce (VOX).
    @Published var handsFree: Bool { didSet { UserDefaults.standard.set(handsFree, forKey: "handsFree"); setTalking(false) } }
    @Published var voxThreshold: Double { didSet { UserDefaults.standard.set(voxThreshold, forKey: "vox") } }
    /// Beep di inizio/fine trasmissione e "roger".
    @Published var sounds: Bool { didSet { UserDefaults.standard.set(sounds, forKey: "sounds") } }
    /// Test eco: il relay rimanda indietro la nostra voce (prova con un solo telefono).
    @Published var echoTest = false
    @Published var micDenied = false
    @Published var isRunning = false
    @Published var nearbyName: String?
    @Published var nearbyConnecting = false
    @Published var relayPeer = false
    @Published var talking = false
    @Published var remoteTalking = false
    @Published var level: Float = 0
    /// Livello della voce dell'altro (anima gli anelli mentre parla).
    @Published var remoteLevel: Float = 0
    /// Latenza verso il relay (ms), nil se non misurata.
    @Published var relayRTT: Int?
    @Published var outputName = "—"
    @Published var error: String?

    private let audio = AudioEngine()
    private var nearby: PeerTransport?
    private var relay: RelayTransport?
    private var voxHoldUntil = Date.distantPast
    private var pressStart: Date?
    private var wasTalkingAtPress = false
    private var demo = false
    // Letti dal thread audio.
    nonisolated(unsafe) private var gateOpen = false

    /// URL relay di default, iniettato in build (variabile RELAY_URL della CI).
    static var defaultRelayURL: String {
        (Bundle.main.object(forInfoDictionaryKey: "RelayURL") as? String).flatMap { $0.hasPrefix("$(") ? nil : $0 } ?? ""
    }

    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "?"
    }

    init() {
        let d = UserDefaults.standard
        if let c = d.string(forKey: "pairCode"), PairCode.normalize(c) != nil {
            pairCode = c
        } else {
            let c = PairCode.generate()
            d.set(c, forKey: "pairCode")
            pairCode = c
        }
        myName = d.string(forKey: "myName") ?? ""
        partnerName = d.string(forKey: "partnerName") ?? ""
        linkMode = LinkMode(rawValue: d.string(forKey: "link") ?? "") ?? .auto
        let savedRelay = d.string(forKey: "relayURL") ?? ""
        relayURL = savedRelay.isEmpty ? Self.defaultRelayURL : savedRelay
        highQuality = d.bool(forKey: "hq")
        handsFree = d.bool(forKey: "handsFree")
        voxThreshold = d.object(forKey: "vox") as? Double ?? 0.1
        sounds = d.object(forKey: "sounds") as? Bool ?? true
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.outputName = AudioEngine.currentOutputName }
        }
        setupRemoteCommands()
        if Self.shared == nil { Self.shared = self }
    }

    var linked: Bool { nearbyName != nil || relayPeer }

    /// Nome con cui ci vede l'altro.
    var displayName: String {
        let n = myName.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? "iPhone" : n
    }

    private var partnerLabel: String { partnerName.isEmpty ? "l'altro" : partnerName }

    var statusText: String {
        if !isRunning { return "Spento" }
        if echoTest { return relayPeer ? "Test eco: parla e ti risenti" : "Test eco: connessione…" }
        if let n = nearbyName { return "Collegato con \(n) · vicino" }
        if relayPeer { return "Collegato con \(partnerLabel) · internet" + (relayRTT.map { " \($0) ms" } ?? "") }
        return nearbyConnecting ? "Connessione…" : "In attesa di \(partnerLabel)…"
    }

    /// Cambia quando cambia qualcosa che richiede di riavviare i collegamenti.
    var configKey: String { "\(pairCode)|\(displayName)|\(linkMode.rawValue)|\(relayURL)|\(highQuality)" }

    /// Da chiamare alla chiusura delle impostazioni: se è cambiata la configurazione, riavvia.
    func settingsClosed(previousKey: String) {
        guard isRunning, !demo, previousKey != configKey else { return }
        stop()
        start()
    }

    /// Imposta il codice dell'altro telefono (testo o link). Restituisce false se non valido.
    @discardableResult
    func joinPair(_ input: String) -> Bool {
        guard let c = PairCode.normalize(input) else { return false }
        pairCode = c
        return true
    }

    func newPairCode() { pairCode = PairCode.generate() }

    var shareText: String {
        "Parliamo con Roger 🎙️ Apri questo link sul tuo iPhone: roger://pair?code=\(pairCode)\noppure in Roger › Impostazioni › «Ho un codice» inserisci: \(PairCode.pretty(pairCode))"
    }

    func startStop() { isRunning ? stop() : start() }

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                self.micDenied = !granted
                guard granted else { self.echoTest = false; self.error = "Roger non può usare il microfono."; return }
                self.begin()
            }
        }
    }

    /// Prova con un solo telefono: via internet, il relay rimanda indietro la tua voce dopo ~1,5 s.
    func startEchoTest() {
        if isRunning { stop() }
        echoTest = true
        start()
    }

    private func begin() {
        error = nil
        let crypto = RoomCrypto(room: pairCode)
        let audio = self.audio

        if linkMode != .internet && !echoTest {
            let t = PeerTransport(roomId: crypto.roomId, name: displayName)
            t.onAudio = { data in audio.play(data, link: .nearby) }
            t.onState = { [weak self] name, connecting in
                guard let self else { return }
                if name != nil && self.nearbyName == nil && !self.relayPeer { self.cue(.linked) }
                self.nearbyName = name
                self.nearbyConnecting = connecting
                if let name { self.partnerName = name }
            }
            t.onRemoteTalking = { [weak self] on in self?.remoteChanged(on) }
            nearby = t
        }
        if linkMode != .nearby || echoTest {
            if let r = RelayTransport(base: relayURL, room: pairCode, echo: echoTest) {
                r.onAudio = { data in audio.play(data, link: .relay) }
                r.onState = { [weak self] present in
                    guard let self else { return }
                    if present && !self.relayPeer && self.nearbyName == nil { self.cue(.linked) }
                    self.relayPeer = present
                    if present && !self.echoTest { self.relay?.send(.hello(self.displayName)) }
                }
                r.onRemoteTalking = { [weak self] on in self?.remoteChanged(on) }
                r.onHello = { [weak self] name in self?.partnerName = name }
                r.onRTT = { [weak self] ms in self?.relayRTT = ms }
                relay = r
            } else if linkMode == .internet || echoTest {
                echoTest = false
                error = "Manca l'indirizzo del relay (Impostazioni › Avanzate)."; return
            }
        }

        let n = nearby, r = relay
        let encoder = ADPCMEncoder()
        audio.onCapturedPacket = { [weak self] data in
            guard let self, self.gateOpen else { return }
            Self.route(.adpcm(encoder.encode(data)), nearby: n, relay: r)
        }
        audio.onPlayLevel = { [weak self] lvl in
            Task { @MainActor in self?.remoteLevel = lvl }
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
    private nonisolated static func route(_ msg: WireMessage, nearby: PeerTransport?, relay: RelayTransport?) {
        if let n = nearby, n.isConnected { n.send(msg) }
        else if let r = relay, r.isConnected { r.send(msg) }
    }

    func stop() {
        setTalking(false)
        nearby?.stop(); nearby = nil
        relay?.stop(); relay = nil
        audio.stop()
        isRunning = false; nearbyName = nil; nearbyConnecting = false; relayPeer = false
        remoteTalking = false; level = 0; echoTest = false; relayRTT = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: Parlato: tocca = parla/smetti, tieni premuto = parla finché tieni

    private func cue(_ c: AudioEngine.Cue) {
        if sounds { audio.playCue(c) }
    }

    /// Quando l'altro chiude la trasmissione: beep "roger".
    private func remoteChanged(_ on: Bool) {
        if remoteTalking && !on { audio.remoteSpurtEnded(); cue(.roger) }
        if !on { remoteLevel = 0 }
        remoteTalking = on
    }

    func setTalking(_ on: Bool) {
        guard talking != on else { return }
        talking = on
        if isRunning && !demo {
            UIImpactFeedbackGenerator(style: on ? .medium : .light).impactOccurred()
            if !handsFree { cue(on ? .talkStart : .talkEnd) }
        }
        gateOpen = on
        let msg = WireMessage.talking(on)
        // Lo stato "parla" è solo informativo: manda su tutti i canali attivi.
        if let n = nearby, n.isConnected { n.send(msg) }
        if let r = relay, r.isConnected { r.send(msg) }
    }

    func pressBegan() {
        guard isRunning, !handsFree, pressStart == nil else { return }
        pressStart = Date()
        wasTalkingAtPress = talking
        if !talking { setTalking(true) }
    }

    func pressEnded() {
        guard let s = pressStart else { return }
        pressStart = nil
        let held = Date().timeIntervalSince(s) > 0.4
        // Tocco breve: accende (resta acceso) o spegne. Pressione lunga: parla solo mentre tieni.
        if held || wasTalkingAtPress { setTalking(false) }
    }

    private func handleLevel(_ lvl: Float) {
        level = lvl
        guard isRunning, handsFree else { return }
        if lvl > Float(voxThreshold) { voxHoldUntil = Date().addingTimeInterval(0.8) }
        setTalking(Date() < voxHoldUntil)
    }

    // MARK: Tasto fisico AirPods (stem/play-pause) e lock screen

    private func setupRemoteCommands() {
        let c = MPRemoteCommandCenter.shared()
        let toggle: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning, !self.handsFree else { return }
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
            MPMediaItemPropertyTitle: "Roger attivo",
            MPMediaItemPropertyArtist: "Premi play/pausa per parlare",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        MPNowPlayingInfoCenter.default().playbackState = .playing
    }

    // MARK: Demo (solo screenshot automatici in CI: `-demo <stato>`)

    func applyDemo(_ state: String) {
        demo = true
        if myName.isEmpty { myName = "Gaetano" }
        partnerName = "Claudia"
        pairCode = "K7QM2XRB4P"
        guard !["off", "settings", "onboarding"].contains(state) else { return }
        isRunning = true
        outputName = "AirPods Pro di Gaetano"
        switch state {
        case "waiting": break
        case "talking": nearbyName = "Claudia"; talking = true; level = 0.35
        case "remote": relayPeer = true; remoteTalking = true; remoteLevel = 0.4
        case "denied": isRunning = false; micDenied = true; error = "Roger non può usare il microfono."
        case "echo": echoTest = true; relayPeer = true
        default: nearbyName = "Claudia"
        }
    }
}
