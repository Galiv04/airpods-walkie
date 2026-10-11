import AVFoundation
import MediaPlayer
import SwiftUI

enum TalkMode: String, CaseIterable, Identifiable {
    case pushToTalk = "Premi"
    case latch = "Tocca"
    case vox = "Voce"
    var id: String { rawValue }
}

/// Collega UI, audio e trasporto.
@MainActor
final class WalkieModel: ObservableObject {
    @Published var room: String { didSet { UserDefaults.standard.set(room, forKey: "room") } }
    @Published var mode: TalkMode { didSet { UserDefaults.standard.set(mode.rawValue, forKey: "mode"); setTalking(false) } }
    @Published var voxThreshold: Double { didSet { UserDefaults.standard.set(voxThreshold, forKey: "vox") } }
    @Published var isRunning = false
    @Published var peerName: String?
    @Published var connecting = false
    @Published var talking = false
    @Published var remoteTalking = false
    @Published var level: Float = 0
    @Published var outputName = "—"
    @Published var error: String?

    private let audio = AudioEngine()
    private var transport: PeerTransport?
    private var voxHoldUntil = Date.distantPast
    // Letti dal thread audio.
    nonisolated(unsafe) private var gateOpen = false

    init() {
        let d = UserDefaults.standard
        room = d.string(forKey: "room") ?? "moto"
        mode = TalkMode(rawValue: d.string(forKey: "mode") ?? "") ?? .pushToTalk
        voxThreshold = d.object(forKey: "vox") as? Double ?? 0.1
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.outputName = AudioEngine.currentOutputName }
        }
        setupRemoteCommands()
    }

    func startStop() { isRunning ? stop() : start() }

    func start() {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            Task { @MainActor in
                guard granted else { self.error = "Permesso microfono negato (Impostazioni › Walkie)."; return }
                self.begin()
            }
        }
    }

    private func begin() {
        error = nil
        let t = PeerTransport(room: room.trimmingCharacters(in: .whitespaces).lowercased())
        let audio = self.audio
        t.onAudio = { data in audio.play(data) }
        t.onState = { [weak self] name, connecting in self?.peerName = name; self?.connecting = connecting }
        t.onRemoteTalking = { [weak self] on in self?.remoteTalking = on }
        transport = t

        audio.onCapturedPacket = { [weak self, weak t] data in
            guard let self, self.gateOpen else { return }
            t?.sendAudio(data)
        }
        audio.onLevel = { [weak self] lvl in
            guard let self else { return }
            Task { @MainActor in self.handleLevel(lvl) }
        }
        do { try audio.start() } catch {
            self.error = "Audio: \(error.localizedDescription)"; return
        }
        t.start()
        isRunning = true
        outputName = AudioEngine.currentOutputName
        UIApplication.shared.isIdleTimerDisabled = true
        updateNowPlaying()
    }

    func stop() {
        setTalking(false)
        transport?.stop(); transport = nil
        audio.stop()
        isRunning = false; peerName = nil; connecting = false; remoteTalking = false; level = 0
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: Talk gating

    func setTalking(_ on: Bool) {
        guard talking != on else { return }
        talking = on
        gateOpen = on
        transport?.sendTalking(on)
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
        ]
    }

    func showMicModes() { AVCaptureDevice.showSystemUserInterface(.microphoneModes) }
}
