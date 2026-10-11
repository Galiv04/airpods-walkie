import SwiftUI

/// Primo avvio: benvenuto → nome → collegamento con l'altro telefono → come si usa.
struct OnboardingView: View {
    @EnvironmentObject var m: WalkieModel
    var onDone: () -> Void
    @State private var step = 0
    @State private var codeInput = ""
    @State private var codeError = false
    @State private var joined = false

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                progress.padding(.top, 12)
                Group {
                    switch step {
                    case 0: welcome
                    case 1: name
                    case 2: pair
                    default: howTo
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .foregroundStyle(Theme.ink)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: step)
    }

    private var progress: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { i in
                Capsule().fill(i <= step ? Theme.clay : Theme.ink.opacity(0.15))
                    .frame(height: 6)
                    .overlay(Capsule().stroke(i <= step ? Theme.ink : .clear, lineWidth: 1.5))
            }
        }
    }

    private func next() { step += 1 }

    private func primary(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(.headline, design: .rounded).weight(.black))
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(Theme.paper)
                .inkCapsule(fill: Theme.clay, shadow: 4)
        }
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(spacing: 10) {
            Text(t).font(.system(size: 30, weight: .black, design: .rounded)).multilineTextAlignment(.center)
            Text(sub).font(.system(.body, design: .rounded)).multilineTextAlignment(.center).opacity(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Passi

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("Logo").resizable().scaledToFit()
                .frame(maxWidth: 220)
                .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 48, style: .continuous).stroke(Theme.ink, lineWidth: 3))
                .background(RoundedRectangle(cornerRadius: 48, style: .continuous).fill(Theme.ink).offset(y: 6))
            title("Roger", "Il walkie-talkie per i tuoi AirPods.\nParla con chi viaggia con te, anche in moto o in aereo, anche col rumore.")
            Spacer()
            primary("Iniziamo", action: next)
        }
    }

    private var name: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "person.crop.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.clay)
            title("Come ti chiami?", "L'altro vedrà «Collegato con …» col tuo nome.")
            TextField("Il tuo nome", text: $m.myName)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words).autocorrectionDisabled()
                .padding(.vertical, 14).padding(.horizontal, 16)
                .inkCapsule()
                .submitLabel(.next).onSubmit(next)
            Spacer()
            primary(m.myName.trimmingCharacters(in: .whitespaces).isEmpty ? "Salta" : "Avanti", action: next)
        }
    }

    private var pair: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            Image(systemName: "link.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.clay)
            title("Collega l'altro telefono", "Si fa una volta sola. Uno invia il proprio codice, l'altro lo inserisce (o tocca il link ricevuto).")
            VStack(spacing: 4) {
                Text("Il tuo codice").font(.caption.weight(.bold)).opacity(0.6)
                Text(PairCode.pretty(m.pairCode))
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .minimumScaleFactor(0.6).lineLimit(1)
            }
            ShareLink(item: m.shareText) {
                Label("Invia il mio codice", systemImage: "square.and.arrow.up")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
                    .inkCapsule()
            }
            HStack(spacing: 10) {
                TextField("Codice dell'altro", text: $codeInput)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .inkCapsule()
                Button {
                    codeError = !m.joinPair(codeInput)
                    joined = !codeError
                } label: {
                    Text("Collega").font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .padding(.vertical, 12).padding(.horizontal, 16)
                        .foregroundStyle(Theme.paper)
                        .inkCapsule(fill: Theme.clay)
                }
                .disabled(codeInput.isEmpty)
            }
            if codeError {
                Text("Codice non valido: sono 10 caratteri, es. K7QM2-XRB4P.")
                    .font(.footnote.weight(.semibold)).foregroundStyle(Theme.clayDark)
            } else if joined {
                Label("Collegato! Ora avete lo stesso codice.", systemImage: "checkmark.circle.fill")
                    .font(.footnote.weight(.bold)).foregroundStyle(Theme.green)
            }
            Spacer(minLength: 8)
            primary(joined ? "Avanti" : "Lo faccio dopo", action: next)
        }
    }

    private var howTo: some View {
        VStack(spacing: 22) {
            Spacer()
            title("Come si usa", "Accendi Roger su entrambi i telefoni con gli AirPods nelle orecchie.")
            VStack(alignment: .leading, spacing: 16) {
                row("hand.tap.fill", "Tocca il pulsante", "per parlare, ritocca per chiudere")
                row("hand.point.up.left.fill", "Oppure tienilo premuto", "e rilascia quando hai finito")
                row("airpodspro", "Oppure premi l'AirPod", "anche a schermo bloccato")
                row("waveform", "Senti un «bip-bip»", "quando l'altro ha finito: tocca a te")
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.paper))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.ink, lineWidth: 2.5))
            .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.ink).offset(y: 4))
            Spacer()
            primary("Tutto chiaro", action: onDone)
        }
    }

    private func row(_ icon: String, _ t: String, _ sub: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.clay)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(t).font(.system(.subheadline, design: .rounded).weight(.heavy))
                Text(sub).font(.system(.footnote, design: .rounded)).opacity(0.7)
            }
        }
    }
}
