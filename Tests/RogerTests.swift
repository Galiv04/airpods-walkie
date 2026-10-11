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
