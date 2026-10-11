import CryptoKit
import Foundation

/// Formato dei messaggi (uguale su Multipeer e relay internet).
/// [tipo:1][payload]. tipo 1 = audio PCM Int16 @ AudioEngine.wireRate mono, tipo 2 = stato "parla" (1 byte),
/// tipo 3 = nome di chi parla (UTF-8, per mostrare "Collegato con …").
enum WireMessage {
    case audio(Data)
    case talking(Bool)
    case hello(String)

    var encoded: Data {
        switch self {
        case .audio(let pcm): var d = Data([1]); d.append(pcm); return d
        case .talking(let on): return Data([2, on ? 1 : 0])
        case .hello(let name): var d = Data([3]); d.append(Data(name.prefix(40).utf8)); return d
        }
    }

    static func decode(_ data: Data) -> WireMessage? {
        guard let t = data.first else { return nil }
        switch t {
        case 1: return .audio(data.dropFirst())
        case 2: return data.count > 1 ? .talking(data[data.startIndex + 1] == 1) : nil
        case 3: return String(data: data.dropFirst(), encoding: .utf8).map { .hello($0) }
        default: return nil
        }
    }
}

/// Cifratura end-to-end per il relay internet: chiave derivata dal codice stanza.
/// Il server vede solo byte cifrati. (Con un codice stanza corto/indovinabile la protezione è debole: usa un codice lungo.)
struct RoomCrypto {
    let key: SymmetricKey
    /// Identificativo anonimo della stanza usato nell'URL del relay.
    let roomId: String

    init(room: String) {
        let seed = SHA256.hash(data: Data(("airwalkie-v1:" + room).utf8))
        key = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: Data(seed)),
                                     salt: Data("airwalkie-salt".utf8), info: Data(), outputByteCount: 32)
        let id = SHA256.hash(data: Data(("airwalkie-room:" + room).utf8))
        roomId = id.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    func seal(_ d: Data) -> Data? { try? ChaChaPoly.seal(d, using: key).combined }

    func open(_ d: Data) -> Data? {
        guard let box = try? ChaChaPoly.SealedBox(combined: d) else { return nil }
        return try? ChaChaPoly.open(box, using: key)
    }
}
