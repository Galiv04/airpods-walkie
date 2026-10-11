import SwiftUI

/// Palette e stile condivisi con l'icona (cartoon a inchiostro: crema, terracotta, contorni neri, ombra "a gradino").
enum Theme {
    static let cream = Color(red: 0.953, green: 0.925, blue: 0.878)
    static let blob = Color(red: 0.925, green: 0.776, blue: 0.667)
    static let clay = Color(red: 0.851, green: 0.467, blue: 0.341)
    static let clayDark = Color(red: 0.729, green: 0.361, blue: 0.251)
    static let ink = Color(red: 0.110, green: 0.094, blue: 0.086)
    static let paper = Color(red: 0.988, green: 0.980, blue: 0.961)
    static let sky = Color(red: 0.478, green: 0.667, blue: 0.784)
    static let green = Color(red: 0.40, green: 0.66, blue: 0.42)
}

extension View {
    /// Capsula con contorno nero e ombra piena sfalsata, come i disegni dell'icona.
    func inkCapsule(fill: Color = Theme.paper, shadow: CGFloat = 3) -> some View {
        background(Capsule().fill(fill))
            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
            .background(Capsule().fill(Theme.ink).offset(y: shadow))
    }
}

struct ContentView: View {
    @EnvironmentObject var m: WalkieModel
    @State private var showSettings = false
    @State private var configAtOpen = ""
    @State private var breathe = false
    @State private var showOnboarding = false
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        GeometryReader { geo in
            // Diametro del pulsante proporzionato allo schermo: niente sbordamenti su iPhone piccoli.
            let d = min(geo.size.width * 0.62, geo.size.height * 0.34, 260)
            VStack(spacing: 0) {
                topBar
                statusBlock.padding(.top, 18)
                Spacer(minLength: 12)
                mainButton(diameter: d)
                Spacer(minLength: 12)
                bottomBlock
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
            .frame(width: geo.size.width, height: geo.size.height)
            .background(background(diameter: d))
        }
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $showSettings, onDismiss: { m.settingsClosed(previousKey: configAtOpen) }) {
            SettingsView().environmentObject(m)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { onboarded = true; showOnboarding = false }.environmentObject(m)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true }
            if let demo = UserDefaults.standard.string(forKey: "demo") {
                if demo == "settings" { openSettings() }
                showOnboarding = demo == "onboarding"
            } else {
                showOnboarding = !onboarded
            }
        }
    }

    private func openSettings() {
        configAtOpen = m.configKey
        showSettings = true
    }

    // MARK: Sfondo (non partecipa al layout)

    private func background(diameter d: CGFloat) -> some View {
        ZStack {
            Theme.cream
            Circle().fill(Theme.blob).frame(width: d * 1.55, height: d * 1.55)
            Image(systemName: "sparkle").font(.system(size: 22, weight: .black))
                .foregroundStyle(Theme.clay).offset(x: -d * 0.62, y: -d * 0.95)
            Image(systemName: "sparkle").font(.system(size: 26, weight: .black))
                .foregroundStyle(Theme.clay).offset(x: d * 0.62, y: -d * 0.55)
            Image(systemName: "sparkle").font(.system(size: 14, weight: .black))
                .foregroundStyle(Theme.ink).offset(x: -d * 0.7, y: d * 0.1)
            Image(systemName: "sparkle").font(.system(size: 18, weight: .black))
                .foregroundStyle(Theme.clayDark).offset(x: d * 0.6, y: d * 0.95)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Barra in alto: nome app + un solo pulsante impostazioni

    private var topBar: some View {
        HStack {
            Text("Roger").font(.system(size: 34, weight: .black, design: .rounded))
            Spacer()
            Button(action: openSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 19, weight: .bold))
                    .frame(width: 46, height: 46)
                    .inkCapsule()
            }
            .accessibilityLabel("Impostazioni")
        }
        .padding(.top, 6)
    }

    // MARK: Stato

    private var statusColor: Color {
        if !m.isRunning { return .gray }
        return m.linked ? Theme.green : Theme.clay
    }

    private var statusBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                Text(m.statusText).font(.system(.subheadline, design: .rounded).weight(.bold))
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 16).padding(.vertical, 9)
            .inkCapsule()

            if m.remoteTalking {
                Label("\(m.partnerName.isEmpty ? "L'altro" : m.partnerName) sta parlando", systemImage: "waveform")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .inkCapsule(fill: Theme.sky)
                    .transition(.scale.combined(with: .opacity))
            } else if m.isRunning {
                Label(m.outputName, systemImage: "airpodspro")
                    .font(.system(.footnote, design: .rounded).weight(.semibold)).opacity(0.65)
                    .lineLimit(1)
            }
            if let e = m.error {
                Text(e).font(.footnote.weight(.semibold)).foregroundStyle(Theme.clayDark)
                    .multilineTextAlignment(.center)
                if m.micDenied {
                    Button {
                        if let u = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(u) }
                    } label: {
                        Label("Consenti il microfono", systemImage: "mic.badge.plus")
                            .font(.system(.footnote, design: .rounded).weight(.heavy))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .inkCapsule()
                    }
                }
            }
        }
        .frame(minHeight: 96, alignment: .top)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: m.remoteTalking)
    }

    // MARK: Pulsante centrale (Avvia / Parla)

    private var fillColor: Color {
        if !m.isRunning { return Theme.paper }
        return m.talking ? Theme.ink : Theme.clay
    }

    private var contentColor: Color {
        if !m.isRunning { return Theme.ink }
        return m.talking ? Theme.cream : Theme.paper
    }

    private var ringColor: Color {
        if m.remoteTalking { return Theme.sky }
        return m.talking ? Theme.clay : Theme.ink.opacity(0.35)
    }

    private func ringScale(_ i: Int) -> CGFloat {
        let base = 1.12 + CGFloat(i) * 0.16
        if m.talking { return base + CGFloat(min(1, m.level * 2)) * 0.12 }
        if m.remoteTalking { return base + CGFloat(min(1, m.remoteLevel * 2)) * 0.12 }
        return base * (breathe ? 1.02 : 0.98)
    }

    private func mainButton(diameter d: CGFloat) -> some View {
        let pressed = m.talking
        return ZStack {
            // Anelli: solo scaleEffect, non allargano il layout.
            if m.isRunning {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 14]))
                        .scaleEffect(ringScale(i))
                        .opacity(1.0 - Double(i) * 0.25)
                }
            }
            Circle().fill(Theme.ink).offset(y: pressed ? 3 : 9)
            Group {
                Circle().fill(fillColor)
                Circle().stroke(Theme.ink, lineWidth: 5)
                VStack(spacing: 8) {
                    Image(systemName: icon).font(.system(size: d * 0.22, weight: .bold))
                    Text(label).font(.system(size: max(14, d * 0.075), weight: .black, design: .rounded))
                        .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
                        .padding(.horizontal, d * 0.12)
                }.foregroundStyle(contentColor)
            }
            .offset(y: pressed ? 6 : 0)
        }
        .frame(width: d, height: d)
        .padding(.vertical, d * 0.2)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if m.isRunning { m.pressBegan() } }
            .onEnded { _ in
                if m.isRunning { m.pressEnded() } else { m.startStop() }
            })
        .animation(.easeOut(duration: 0.12), value: m.level)
        .animation(.easeOut(duration: 0.12), value: m.remoteLevel)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: m.talking)
        .animation(.easeInOut(duration: 0.25), value: m.isRunning)
        .accessibilityElement()
        .accessibilityLabel(m.isRunning ? (m.talking ? "Stai parlando. Tocca per smettere" : "Tocca per parlare") : "Avvia Roger")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { if m.isRunning { m.setTalking(!m.talking) } else { m.startStop() } }
    }

    private var icon: String {
        if !m.isRunning { return "power" }
        if m.handsFree { return m.talking ? "waveform" : "ear" }
        return m.talking ? "mic.fill" : "mic"
    }

    private var label: String {
        if !m.isRunning { return "AVVIA" }
        if m.handsFree { return m.talking ? "TI SENTO" : "PARLA PURE" }
        return m.talking ? "IN ONDA" : "PARLA"
    }

    // MARK: In basso: una riga di aiuto + Ferma

    private var hint: String {
        if !m.isRunning { return "Tocca per accendere" }
        if m.echoTest { return "Parla: dopo un secondo e mezzo ti risenti negli AirPods" }
        if m.handsFree { return "Mani libere: trasmette quando parli" }
        return m.talking ? "Tocca di nuovo per chiudere" : "Tocca per parlare · tieni premuto e rilascia · o premi l'AirPod"
    }

    private var bottomBlock: some View {
        VStack(spacing: 14) {
            Text(hint)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .multilineTextAlignment(.center).opacity(0.7)
                .fixedSize(horizontal: false, vertical: true)
            if m.isRunning {
                Button { m.startStop() } label: {
                    Label("Spegni", systemImage: "power")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 24).padding(.vertical, 11)
                        .inkCapsule()
                }
            }
        }
        .frame(minHeight: 90, alignment: .top)
    }
}

// MARK: - Impostazioni

struct SettingsView: View {
    @EnvironmentObject var m: WalkieModel
    @Environment(\.dismiss) private var dismiss
    @State private var askCode = false
    @State private var codeInput = ""
    @State private var codeError = false
    @State private var confirmNew = false

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text("Codice coppia").font(.caption.weight(.bold)).opacity(0.6)
                        Text(PairCode.pretty(m.pairCode))
                            .font(.system(size: 30, weight: .black, design: .monospaced))
                            .textSelection(.enabled)
                            .minimumScaleFactor(0.6).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 6)
                    ShareLink(item: m.shareText) {
                        Label("Invia il codice all'altro telefono", systemImage: "square.and.arrow.up")
                    }
                    Button { codeInput = ""; askCode = true } label: {
                        Label("Ho un codice dall'altro telefono", systemImage: "keyboard")
                    }
                } header: {
                    Text("Coppia")
                } footer: {
                    Text("Si fa una volta sola: su un telefono tocca «Invia il codice», sull'altro apri il link ricevuto (o tocca «Ho un codice»). Il codice è unico e fa anche da chiave di cifratura.")
                }

                Section {
                    TextField("Es. Gaetano", text: $m.myName)
                        .textInputAutocapitalization(.words).autocorrectionDisabled()
                } header: {
                    Text("Il tuo nome")
                } footer: {
                    Text("Così l'altro vede «Collegato con …».")
                }

                Section {
                    Toggle("Mani libere (parla e trasmette)", isOn: $m.handsFree)
                    if m.handsFree {
                        VStack(alignment: .leading) {
                            Text("Sensibilità voce").font(.subheadline)
                            HStack {
                                Image(systemName: "speaker.wave.3.fill").font(.caption)
                                Slider(value: $m.voxThreshold, in: 0.02...0.5)
                                Image(systemName: "speaker.wave.1.fill").font(.caption)
                            }
                        }
                    }
                } header: {
                    Text("Come parli")
                } footer: {
                    Text(m.handsFree
                         ? "Trasmette da solo quando parli. Se il rumore lo attiva per sbaglio, sposta il cursore verso destra."
                         : "Tocca il pulsante per parlare e ritocca per chiudere, oppure tienilo premuto e rilascia. Funziona anche premendo l'AirPod (play/pausa).")
                }

                Section {
                    Toggle("Suoni (bip di inizio e fine)", isOn: $m.sounds)
                    Button {
                        m.startEchoTest()
                        dismiss()
                    } label: {
                        Label("Prova da solo (test eco via internet)", systemImage: "arrow.uturn.backward.circle")
                    }
                } header: {
                    Text("Suoni e prova")
                } footer: {
                    Text("Il test eco ti rimanda la tua voce dopo 1,5 secondi: verifica AirPods, microfono e internet senza l'altro telefono.")
                }

                Section {
                    Text("Con Roger acceso apri il Centro di Controllo, tocca «Modalità microfono» e scegli «Isolamento vocale»: riduce vento e motore sulla tua voce.")
                        .font(.footnote).foregroundStyle(Theme.ink.opacity(0.7))
                } header: {
                    Text("Isolamento vocale")
                }

                Section {
                    Picker("Collegamento", selection: $m.linkMode) {
                        ForEach(LinkMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    TextField("Indirizzo relay", text: $m.relayURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).font(.footnote)
                    Toggle("Audio alta qualità AirPods (sperimentale, iOS 26)", isOn: $m.highQuality)
                    Button("Genera un nuovo codice coppia", role: .destructive) { confirmNew = true }
                } header: {
                    Text("Avanzate")
                } footer: {
                    Text("Auto: collegamento diretto se siete vicini, altrimenti via internet. Le modifiche si applicano alla chiusura di questa schermata. Versione \(WalkieModel.appVersion).")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .tint(Theme.clay)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") { dismiss() }.fontWeight(.heavy)
                }
            }
            .alert("Codice dell'altro telefono", isPresented: $askCode) {
                TextField("XXXXX-XXXXX", text: $codeInput)
                    .textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("Annulla", role: .cancel) {}
                Button("Collega") { codeError = !m.joinPair(codeInput) }
            } message: {
                Text("Incolla o scrivi il codice di 10 caratteri ricevuto.")
            }
            .alert("Codice non valido", isPresented: $codeError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Il codice ha 10 caratteri (lettere e numeri), es. K7QM2-XRB4P.")
            }
            .confirmationDialog("Nuovo codice coppia?", isPresented: $confirmNew, titleVisibility: .visible) {
                Button("Genera nuovo codice", role: .destructive) { m.newPairCode() }
            } message: {
                Text("L'altro telefono non sarà più collegato finché non gli invii il nuovo codice.")
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.light)
    }
}
