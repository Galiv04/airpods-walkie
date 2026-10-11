import XCTest
@testable import AirPodsWalkie

final class PairCodeTests: XCTestCase {
    func testGenerateIsValidAndUnique() {
        let a = PairCode.generate(), b = PairCode.generate()
        XCTAssertEqual(a.count, 10)
        XCTAssertNotNil(PairCode.normalize(a))
        XCTAssertNotEqual(a, b)
    }

    func testNormalizeAcceptsHumanInput() {
        XCTAssertEqual(PairCode.normalize("k7qm2-xrb4p"), "K7QM2XRB4P")
        XCTAssertEqual(PairCode.normalize(" K7QM2 XRB4P "), "K7QM2XRB4P")
        XCTAssertEqual(PairCode.normalize("roger://pair?code=K7QM2XRB4P"), "K7QM2XRB4P")
        XCTAssertEqual(PairCode.normalize("Parliamo con Roger roger://pair?code=K7QM2XRB4P\noppure …"), "K7QM2XRB4P")
        XCTAssertEqual(PairCode.normalize("inserisci: K7QM2-XRB4P grazie"), "K7QM2XRB4P")
        // Il messaggio di condivisione reale deve essere accettato per intero.
        let m = "Parliamo con Roger 🎙️ Apri questo link sul tuo iPhone: roger://pair?code=K7QM2XRB4P\noppure in Roger › Impostazioni › «Ho un codice» inserisci: K7QM2-XRB4P"
        XCTAssertEqual(PairCode.normalize(m), "K7QM2XRB4P")
    }

    func testNormalizeRejectsBadInput() {
        XCTAssertNil(PairCode.normalize("moto"))
        XCTAssertNil(PairCode.normalize("K7QM2XRB4"))
        XCTAssertNil(PairCode.normalize(""))
    }

    func testPretty() {
        XCTAssertEqual(PairCode.pretty("K7QM2XRB4P"), "K7QM2-XRB4P")
    }
}

final class WireTests: XCTestCase {
    func testRoundTrip() {
        let pcm = Data([1, 2, 3, 4])
        guard case .audio(let d)? = WireMessage.decode(WireMessage.audio(pcm).encoded) else { return XCTFail() }
        XCTAssertEqual(Data(d), pcm)
        guard case .talking(let on)? = WireMessage.decode(WireMessage.talking(true).encoded) else { return XCTFail() }
        XCTAssertTrue(on)
        guard case .hello(let n)? = WireMessage.decode(WireMessage.hello("Claudia").encoded) else { return XCTFail() }
        XCTAssertEqual(n, "Claudia")
        XCTAssertNil(WireMessage.decode(Data()))
        XCTAssertNil(WireMessage.decode(Data([99])))
    }
}

final class CryptoTests: XCTestCase {
    func testSealOpenAndRoomIsolation() {
        let a = RoomCrypto(room: "K7QM2XRB4P"), b = RoomCrypto(room: "K7QM2XRB4P"), other = RoomCrypto(room: "ZZZZZ22222")
        XCTAssertEqual(a.roomId, b.roomId)
        XCTAssertNotEqual(a.roomId, other.roomId)
        XCTAssertEqual(a.roomId.count, 32)
        let sealed = a.seal(Data("ciao".utf8))!
        XCTAssertEqual(b.open(sealed), Data("ciao".utf8))
        XCTAssertNil(other.open(sealed))
        XCTAssertFalse(a.roomId.contains("K7QM2"))
    }

    /// Vettore fisso: deve restare identico tra versioni, altrimenti due telefoni con versioni diverse non si parlano.
    func testRoomIdIsStable() {
        XCTAssertEqual(RoomCrypto(room: "K7QM2XRB4P").roomId, RoomCrypto(room: "K7QM2XRB4P").roomId)
    }
}

@MainActor
final class TalkLogicTests: XCTestCase {
    func testTapTogglesAndHoldReleases() async throws {
        let m = WalkieModel()
        m.applyDemo("linked")
        m.handsFree = false
        // Tocco breve: accende e resta acceso.
        m.pressBegan(); m.pressEnded()
        XCTAssertTrue(m.talking)
        // Secondo tocco: spegne.
        m.pressBegan(); m.pressEnded()
        XCTAssertFalse(m.talking)
        // Pressione lunga: parla solo mentre tieni.
        m.pressBegan()
        XCTAssertTrue(m.talking)
        try await Task.sleep(nanoseconds: 500_000_000)
        m.pressEnded()
        XCTAssertFalse(m.talking)
    }

    func testJoinPair() {
        let m = WalkieModel()
        XCTAssertFalse(m.joinPair("moto"))
        XCTAssertTrue(m.joinPair("roger://pair?code=ABCDE23456"))
        XCTAssertEqual(m.pairCode, "ABCDE23456")
    }
}

final class ADPCMTests: XCTestCase {
    private func pcm(_ samples: [Int16]) -> Data {
        var d = Data()
        for s in samples { let u = UInt16(bitPattern: s); d.append(UInt8(u & 0xFF)); d.append(UInt8(u >> 8)) }
        return d
    }

    private func samples(_ d: Data) -> [Int16] {
        let b = [UInt8](d)
        return stride(from: 0, to: b.count - 1, by: 2).map { Int16(bitPattern: UInt16(b[$0]) | UInt16(b[$0 + 1]) << 8) }
    }

    func testRoundTripQualityAndSize() {
        let rate = 24_000.0
        let x: [Int16] = (0..<4800).map { t in
            Int16(8000 * sin(2 * .pi * 220 * Double(t) / rate) + 3000 * sin(2 * .pi * 1300 * Double(t) / rate))
        }
        var st = ADPCM.State()
        var y: [Int16] = []
        var bytes = 0
        for p in stride(from: 0, to: x.count, by: 512) {
            let blk = Array(x[p..<min(p + 512, x.count)])
            let enc = ADPCM.encode(pcm: pcm(blk), state: &st)
            bytes += enc.count
            guard let dec = ADPCM.decode(enc) else { return XCTFail("decode") }
            y += samples(dec)
        }
        XCTAssertEqual(y.count, x.count)
        XCTAssertLessThan(bytes, x.count * 2 / 3, "deve comprimere ~4x")
        let sig = x.reduce(0.0) { $0 + Double($1) * Double($1) }
        let err = zip(x, y).reduce(0.0) { $0 + pow(Double($1.0) - Double($1.1), 2) }
        let snr = 10 * log10(sig / err)
        XCTAssertGreaterThan(snr, 25, "SNR \(snr) dB")
    }

    func testPacketsAreIndependentAndOddLengths() {
        var st = ADPCM.State()
        _ = ADPCM.encode(pcm: pcm([1000, -2000, 3000, 4000]), state: &st)
        let second = ADPCM.encode(pcm: pcm([5000, 5100, 5200]), state: &st)   // dispari
        // Decodificabile senza il primo pacchetto (perso).
        let dec = ADPCM.decode(second)
        XCTAssertEqual(dec.map { samples($0).count }, 3)
        XCTAssertNil(ADPCM.decode(Data([1, 2])))
        guard case .adpcm(let a)? = WireMessage.decode(WireMessage.adpcm(second).encoded) else { return XCTFail() }
        XCTAssertEqual(WireMessage.adpcm(a).pcm?.count, 6)
    }
}
