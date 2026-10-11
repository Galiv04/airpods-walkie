import Foundation

/// Buffer anti-jitter per la voce in arrivo (Float mono a `AudioEngine.wireRate`).
///
/// Idee prese da Chromium remoting / Mumble / NetEQ, in versione semplice:
/// - **pre-roll** a inizio frase (60 ms da vicino, 120 ms via internet) prima di iniziare a suonare;
/// - **underrun** (la rete si ferma a metà frase): breve dissolvenza, silenzio, poi si ri-riempie il pre-roll
///   invece di suonare a scatti; il pre-roll cresce di 20 ms per volta (adattivo) e cala dopo frasi pulite;
/// - **overrun** (raffica dopo uno stallo TCP): oltre `target + margine` si scartano i campioni più vecchi,
///   così la latenza non si accumula;
/// - **fine frase** (`endOfSpurt`): si suona quello che resta senza aspettare il pre-roll.
///
/// Thread-safe: `push` dai thread di rete, `render` dal thread audio.
final class JitterBuffer {
    static let rate = 24_000
    private static func ms(_ v: Int) -> Int { v * rate / 1000 }

    enum Link { case nearby, relay }

    private let lock = NSLock()
    private var ring: [Float]
    private var readIdx = 0
    private var count = 0
    private var playing = false
    private var ending = false
    private var fadeIn = false
    private var lastPush: UInt64 = 0

    private(set) var link: Link = .nearby
    /// Pre-roll attuale in campioni (adattivo).
    private(set) var target: Int
    private var cleanSpurts = 0
    private var underrunThisSpurt = false
    /// Statistiche (diagnostica).
    private(set) var underruns = 0
    private(set) var droppedFrames = 0

    private let fadeLen = 120  // 5 ms
    /// Se arriva audio e poi niente per questo tempo, suona quello che c'è anche sotto il pre-roll.
    private let idleFlushNanos: UInt64 = 150_000_000

    init(capacitySeconds: Double = 2) {
        ring = [Float](repeating: 0, count: Int(Double(Self.rate) * capacitySeconds))
        target = Self.ms(60)
    }

    private var baseTarget: Int { link == .nearby ? Self.ms(60) : Self.ms(120) }
    private var maxTarget: Int { link == .nearby ? Self.ms(160) : Self.ms(300) }
    /// Oltre target + margine si scarta il vecchio.
    private var overrunMargin: Int { link == .nearby ? Self.ms(100) : Self.ms(180) }

    static func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

    /// Livello di riempimento in campioni (per test/diagnostica).
    var buffered: Int { lock.lock(); defer { lock.unlock() }; return count }
    var isPlaying: Bool { lock.lock(); defer { lock.unlock() }; return playing }

    func push(_ samples: [Float], link: Link, now: UInt64 = JitterBuffer.now()) {
        lock.lock(); defer { lock.unlock() }
        if link != self.link {
            self.link = link
            target = max(baseTarget, min(target, maxTarget))
        }
        lastPush = now
        ending = false
        let cap = ring.count
        for s in samples {
            if count == cap { readIdx = (readIdx + 1) % cap; count -= 1; droppedFrames += 1 }
            ring[(readIdx + count) % cap] = s
            count += 1
        }
        // Overrun: torna al target scartando i campioni più vecchi (latenza sotto controllo).
        if count > target + overrunMargin {
            let drop = count - target
            readIdx = (readIdx + drop) % cap
            count -= drop
            droppedFrames += drop
            fadeIn = true
        }
    }

    /// L'altro ha smesso di parlare: suona il resto senza aspettare il pre-roll.
    func endOfSpurt() {
        lock.lock(); defer { lock.unlock() }
        ending = true
        if count > 0 { playing = true }
        finishSpurtStats()
    }

    func reset() {
        lock.lock(); defer { lock.unlock() }
        readIdx = 0; count = 0; playing = false; ending = false; fadeIn = false
    }

    /// Riempie `out` con `n` campioni. Restituisce false se ha scritto solo silenzio.
    @discardableResult
    func render(into out: UnsafeMutablePointer<Float>, frames n: Int, now: UInt64 = JitterBuffer.now()) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if !playing {
            let stale = count > 0 && now > lastPush && now - lastPush > idleFlushNanos
            if count >= target || stale {
                playing = true
                fadeIn = true
            } else {
                out.initialize(repeating: 0, count: n)
                return false
            }
        }
        let cap = ring.count
        let take = min(n, count)
        for i in 0..<take { out[i] = ring[(readIdx + i) % cap] }
        if fadeIn {
            let f = min(fadeLen, take)
            for i in 0..<f { out[i] *= Float(i) / Float(f) }
            fadeIn = false
        }
        readIdx = (readIdx + take) % cap
        count -= take
        if take < n {
            // Finito il buffer: dissolvenza sull'ultimo pezzo per evitare il "click", poi silenzio.
            let f = min(fadeLen, take)
            for i in 0..<f { out[take - f + i] *= Float(f - i) / Float(f) }
            (out + take).initialize(repeating: 0, count: n - take)
            playing = false
            if ending {
                ending = false
            } else if take > 0 || (now >= lastPush && now - lastPush < idleFlushNanos) {
                // Underrun a metà frase: pre-roll più lungo (fino al massimo).
                underruns += 1
                underrunThisSpurt = true
                target = min(maxTarget, target + Self.ms(20))
            }
        }
        return take > 0
    }

    /// Dopo 3 frasi senza underrun il pre-roll torna giù di 10 ms (fino al valore base).
    private func finishSpurtStats() {
        if underrunThisSpurt {
            cleanSpurts = 0
        } else {
            cleanSpurts += 1
            if cleanSpurts >= 3 { target = max(baseTarget, target - Self.ms(10)); cleanSpurts = 0 }
        }
        underrunThisSpurt = false
    }
}
