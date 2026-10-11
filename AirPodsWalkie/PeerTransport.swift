import Foundation
import MultipeerConnectivity
import UIKit

/// Link diretto iPhone <-> iPhone via MultipeerConnectivity (Bluetooth/Wi-Fi peer-to-peer).
/// Funziona senza internet e in modalità aereo (con Bluetooth/Wi-Fi accesi).
/// Entrambi i telefoni fanno advertise + browse; si collegano solo se hanno lo stesso "codice stanza".
final class PeerTransport: NSObject {
    private static let serviceType = "airwalkie"

    private let myPeer: MCPeerID
    private var session: MCSession
    private var advertiser: MCNearbyServiceAdvertiser
    private var browser: MCNearbyServiceBrowser
    private let room: String

    /// Chiamato (su thread arbitrario) per ogni pacchetto audio ricevuto.
    var onAudio: ((Data) -> Void)?
    /// Chiamato sul main thread quando cambia lo stato del collegamento.
    var onState: ((_ peerName: String?, _ connecting: Bool) -> Void)?
    /// Chiamato sul main thread quando l'altro cambia stato "sta parlando".
    var onRemoteTalking: ((Bool) -> Void)?

    private enum Header: UInt8 { case audio = 1, talking = 2 }

    init(room: String) {
        self.room = room
        let suffix = String(UUID().uuidString.prefix(4))
        myPeer = MCPeerID(displayName: "\(UIDevice.current.name)#\(suffix)")
        session = MCSession(peer: myPeer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeer, discoveryInfo: ["room": room],
                                               serviceType: Self.serviceType)
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
        DispatchQueue.main.async { self.onState?(nil, false) }
    }

    func stop() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    var isConnected: Bool { !session.connectedPeers.isEmpty }

    func sendAudio(_ pcm: Data) {
        guard isConnected else { return }
        var d = Data([Header.audio.rawValue]); d.append(pcm)
        try? session.send(d, toPeers: session.connectedPeers, with: .unreliable)
    }

    func sendTalking(_ on: Bool) {
        guard isConnected else { return }
        let d = Data([Header.talking.rawValue, on ? 1 : 0])
        try? session.send(d, toPeers: session.connectedPeers, with: .reliable)
    }
}

extension PeerTransport: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected: self.onState?(peerID.displayName.components(separatedBy: "#").first, false)
            case .connecting: self.onState?(nil, true)
            case .notConnected:
                self.onState?(nil, false)
                self.onRemoteTalking?(false)
            @unknown default: break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let h = data.first, let header = Header(rawValue: h) else { return }
        switch header {
        case .audio: onAudio?(data.dropFirst())
        case .talking:
            let on = data.count > 1 && data[data.startIndex + 1] == 1
            DispatchQueue.main.async { self.onRemoteTalking?(on) }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerTransport: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Accetta solo inviti della stessa stanza.
        let ok = context.flatMap { String(data: $0, encoding: .utf8) } == room && !isConnected
        invitationHandler(ok, ok ? session : nil)
    }
}

extension PeerTransport: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard info?["room"] == room, !isConnected else { return }
        // Per evitare inviti incrociati, invita solo chi ha il nome "minore".
        guard myPeer.displayName < peerID.displayName else { return }
        browser.invitePeer(peerID, to: session, withContext: room.data(using: .utf8), timeout: 15)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
