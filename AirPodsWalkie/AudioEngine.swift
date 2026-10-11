import AVFoundation
import Foundation

/// Cattura il microfono (AirPods via HFP), lo converte in PCM Int16 16 kHz mono e riproduce
/// l'audio ricevuto. Usa `.voiceChat` + voice processing per cancellazione rumore/eco.
final class AudioEngine {
    static let wireRate: Double = 16_000

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let wireFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: wireRate, channels: 1, interleaved: true)!
    private let playFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: wireRate, channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var running = false

    private let pendingLock = NSLock()
    private var pendingBuffers = 0
    private let maxPendingBuffers = 12   // ~250 ms: oltre, scarta per non accumulare latenza

    /// Pacchetto PCM Int16 pronto da inviare (thread audio).
    var onCapturedPacket: ((Data) -> Void)?
    /// Livello microfono 0...1 (thread audio).
    var onLevel: ((Float) -> Void)?

    func start() throws {
        guard !running else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat,
                                options: [.allowBluetooth, .defaultToSpeaker])
        try session.setPreferredSampleRate(Self.wireRate)
        try session.setActive(true)

        // Voice processing = AEC + noise suppression + AGC (deve precedere l'avvio del motore).
        try? engine.inputNode.setVoiceProcessingEnabled(true)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: playFormat)

        let input = engine.inputNode
        let inFormat = input.outputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: wireFormat)
        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            self?.handleCaptured(buf)
        }

        engine.prepare()
        try engine.start()
        player.play()
        running = true
    }

    func stop() {
        guard running else { return }
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

    /// Riproduce un pacchetto PCM Int16 ricevuto.
    func play(_ data: Data) {
        guard running else { return }
        let n = data.count / 2
        guard n > 0, let buf = AVAudioPCMBuffer(pcmFormat: playFormat, frameCapacity: AVAudioFrameCount(n)) else { return }

        pendingLock.lock()
        if pendingBuffers >= maxPendingBuffers { pendingLock.unlock(); return }
        pendingBuffers += 1
        pendingLock.unlock()

        buf.frameLength = AVAudioFrameCount(n)
        let dst = buf.floatChannelData![0]
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<n { dst[i] = Float(Int16(littleEndian: src[i])) / 32768 }
        }
        player.scheduleBuffer(buf) { [weak self] in
            guard let self else { return }
            self.pendingLock.lock(); self.pendingBuffers -= 1; self.pendingLock.unlock()
        }
    }

    /// Nome del dispositivo di uscita attuale (es. "AirPods di Gaetano").
    static var currentOutputName: String {
        AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "—"
    }
}
