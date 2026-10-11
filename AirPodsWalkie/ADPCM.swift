import Foundation

/// IMA ADPCM: 4 bit per campione invece di 16 → un quarto dei dati (24 kHz mono ≈ 12 KB/s invece di 48 KB/s).
/// Ogni pacchetto porta nell'intestazione lo stato del codec, quindi è decodificabile da solo:
/// un pacchetto perso non rovina i successivi.
///
/// Pacchetto: [predittore Int16 LE][indice UInt8][campioni UInt16 LE][nibble…] (nibble basso per primo).
enum ADPCM {
    static let indexTable: [Int] = [-1, -1, -1, -1, 2, 4, 6, 8, -1, -1, -1, -1, 2, 4, 6, 8]
    static let stepTable: [Int] = [
        7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97,
        107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796,
        876, 963, 1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749, 3024, 3327, 3660, 4026, 4428,
        4871, 5358, 5894, 6484, 7132, 7845, 8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
        22385, 24623, 27086, 29794, 32767,
    ]
    static let headerSize = 5

    struct State {
        var predictor = 0
        var index = 0
    }

    /// Codifica un blocco PCM Int16 LE. `state` prosegue tra un pacchetto e l'altro (continuità del suono).
    static func encode(pcm: Data, state: inout State) -> Data {
        let n = pcm.count / 2
        var out = Data(capacity: headerSize + (n + 1) / 2)
        let p = Int16(clamping: state.predictor)
        out.append(UInt8(truncatingIfNeeded: UInt16(bitPattern: p)))
        out.append(UInt8(truncatingIfNeeded: UInt16(bitPattern: p) >> 8))
        out.append(UInt8(state.index))
        out.append(UInt8(truncatingIfNeeded: n))
        out.append(UInt8(truncatingIfNeeded: n >> 8))
        let raw = [UInt8](pcm)
        var byte: UInt8 = 0
        for i in 0..<n {
            let sample = Int(Int16(bitPattern: UInt16(raw[i * 2]) | UInt16(raw[i * 2 + 1]) << 8))
            let nib = encodeSample(sample, &state)
            if i % 2 == 0 { byte = nib } else { out.append(byte | nib << 4) }
        }
        if n % 2 == 1 { out.append(byte) }
        return out
    }

    /// Decodifica un pacchetto in PCM Int16 LE; nil se malformato.
    static func decode(_ data: Data) -> Data? {
        let d = [UInt8](data)
        guard d.count >= headerSize else { return nil }
        var state = State(predictor: Int(Int16(bitPattern: UInt16(d[0]) | UInt16(d[1]) << 8)), index: Int(d[2]))
        let n = Int(UInt16(d[3]) | UInt16(d[4]) << 8)
        guard state.index <= 88, d.count >= headerSize + (n + 1) / 2 else { return nil }
        var out = [UInt8](repeating: 0, count: n * 2)
        for i in 0..<n {
            let b = d[headerSize + i / 2]
            let nib = i % 2 == 0 ? b & 0x0F : b >> 4
            let s = UInt16(bitPattern: Int16(decodeSample(nib, &state)))
            out[i * 2] = UInt8(s & 0xFF)
            out[i * 2 + 1] = UInt8(s >> 8)
        }
        return Data(out)
    }

    private static func encodeSample(_ sample: Int, _ st: inout State) -> UInt8 {
        var diff = sample - st.predictor
        var nib: UInt8 = 0
        if diff < 0 { nib = 8; diff = -diff }
        var step = stepTable[st.index]
        var delta = step >> 3
        if diff >= step { nib |= 4; diff -= step; delta += step }
        step >>= 1
        if diff >= step { nib |= 2; diff -= step; delta += step }
        step >>= 1
        if diff >= step { nib |= 1; delta += step }
        st.predictor = max(-32768, min(32767, st.predictor + (nib & 8 != 0 ? -delta : delta)))
        st.index = max(0, min(88, st.index + indexTable[Int(nib)]))
        return nib
    }

    private static func decodeSample(_ nib: UInt8, _ st: inout State) -> Int {
        let step = stepTable[st.index]
        var delta = step >> 3
        if nib & 4 != 0 { delta += step }
        if nib & 2 != 0 { delta += step >> 1 }
        if nib & 1 != 0 { delta += step >> 2 }
        st.predictor = max(-32768, min(32767, st.predictor + (nib & 8 != 0 ? -delta : delta)))
        st.index = max(0, min(88, st.index + indexTable[Int(nib)]))
        return st.predictor
    }
}

/// Codificatore con stato, usato dal thread audio (un solo chiamante).
final class ADPCMEncoder {
    private var state = ADPCM.State()
    func encode(_ pcm: Data) -> Data { ADPCM.encode(pcm: pcm, state: &state) }
    func reset() { state = ADPCM.State() }
}
