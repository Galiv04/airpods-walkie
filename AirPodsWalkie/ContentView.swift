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
}

extension View {
    /// Capsula con contorno nero e ombra piena sfalsata, come i disegni dell'icona.
    func inkCapsule(fill: Color = Theme.paper, shadow: CGFloat = 3) -> some View {
        background(Capsule().fill(fill))
            .overlay(Capsule().stroke(Theme.ink, lineWidth: 2.5))
            .background(Capsule().fill(Theme.ink).offset(y: shadow))
    }
}

private struct Sparkle: View {
    var color: Color
    var body: some View {
        Image(systemName: "sparkle").font(.system(size: 22, weight: .black)).foregroundStyle(color)
    }
}

struct ContentView: View {
    @EnvironmentObject var m: WalkieModel
    @State private var showSettings = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                titleBlock.padding(.top, 14)
                Spacer(minLength: 8)
                mainButton
                Spacer(minLength: 8)
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .foregroundStyle(Theme.ink)
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(m)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { breathe = true } }
    }

    // MARK: Sfondo

    private var background: some View {
        ZStack {
            Theme.cream
            Circle().fill(Theme.blob).frame(width: 470, height: 470).offset(y: 20)
            Sparkle(color: Theme.clay).offset(x: -140, y: -250)
            Sparkle(color: Theme.ink).scaleEffect(0.6).offset(x: -165, y: -60)
            Sparkle(color: Theme.clay).scaleEffect(1.2).offset(x: 150, y: -120)
            Sparkle(color: Theme.clayDark).scaleEffect(0.8).offset(x: 135, y: 290)
        }.ignoresSafeArea()
    }

    // MARK: Barra in alto

    private var topBar: some View {
        HStack {
            Button { showSettings = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.wave.2.fill")
                    Text(m.room.isEmpty ? "Stanza" : m.room).lineLimit(1)
                }
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
                .padding(.horizontal, 16).padding(.vertical, 10)
                .inkCapsule()
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .inkCapsule()
            }
        }
    }

    // MARK: Titolo + stato

    private var statusColor: Color { !m.isRunning ? Color.gray : (m.linked ? Color.green : Theme.clay) }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("Roger").font(.system(size: 40, weight: .black, design: .rounded))
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
                Text(m.statusText).font(.system(.subheadline, design: .rounded).weight(.bold))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .inkCapsule()

            if m.isRunning {
                Label(m.outputName, systemImage: "airpodspro")
                    .font(.system(.footnote, design: .rounded).weight(.semibold)).opacity(0.6)
            }
            if m.remoteTalking {
                Label("L'altro sta parlando", systemImage: "waveform")
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .inkCapsule(fill: Theme.sky)
                    .transition(.scale.combined(with: .opacity))
            }
            if let e = m.error {
                Text(e).font(.footnote.weight(.semibold)).foregroundStyle(Theme.clayDark).multilineTextAlignment(.center)
            }
        }
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

    private func ringScale(_ lvl: CGFloat) -> CGFloat {
        if m.talking { return 1 + lvl * 0.14 }
        return breathe ? 1.03 : 0.98
    }

    private var mainButton: some View {
        let lvl = CGFloat(min(1, m.level * 2))
        let pressed = m.talking
        return ZStack {
            if m.isRunning {
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(m.remoteTalking ? Theme.sky : (m.talking ? Theme.clay : Theme.ink.opacity(0.35)),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [2, 14]))
                        .frame(width: 262 + CGFloat(i) * 44, height: 262 + CGFloat(i) * 44)
                        .scaleEffect(ringScale(lvl))
                        .opacity(1.0 - Double(i) * 0.25)
                        .animation(.easeOut(duration: 0.12), value: m.level)
                }
            }
            ZStack {
                Circle().fill(Theme.ink).offset(y: pressed ? 3 : 9)
                Circle().fill(fillColor)
                Circle().stroke(Theme.ink, lineWidth: 5)
                VStack(spacing: 10) {
                    Image(systemName: icon).font(.system(size: 56, weight: .bold))
                    Text(label).font(.system(.headline, design: .rounded).weight(.black)).multilineTextAlignment(.center)
                }.foregroundStyle(contentColor)
            }
            .frame(width: 232, height: 232)
            .offset(y: pressed ? 6 : 0)
        }
        .frame(height: 340)
        .contentShape(Circle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if m.isRunning, m.mode == .pushToTalk, !m.talking { m.pttChanged(pressed: true) }
            }
            .onEnded { _ in
                if !m.isRunning { m.startStop() }
                else if m.mode == .pushToTalk { m.pttChanged(pressed: false) }
                else if m.mode == .latch { m.pttChanged(pressed: true) }
            })
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: m.talking)
        .animation(.easeInOut(duration: 0.25), value: m.isRunning)
    }

    private var icon: String {
        if !m.isRunning { return "power" }
        switch m.mode {
        case .vox: return m.talking ? "waveform" : "ear"
        default: return m.talking ? "mic.fill" : "mic"
        }
    }

    private var label: String {
        if !m.isRunning { return "AVVIA" }
        switch m.mode {
        case .pushToTalk: return m.talking ? "PARLI" : "TIENI PREMUTO"
        case .latch: return m.talking ? "PARLI\ntocca per finire" : "TOCCA PER PARLARE"
        case .vox: return m.talking ? "PARLI" : "ASCOLTO VOCE…"
        }
    }

    // MARK: Barra in basso

    private var bottomBar: some View {
        VStack(spacing: 16) {
            HStack(spacing: 4) {
                ForEach(TalkMode.allCases) { mode in
                    Button { m.mode = mode } label: {
                        Text(mode.rawValue).font(.system(.subheadline, design: .rounded).weight(.heavy))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(m.mode == mode ? Theme.clay : .clear, in: Capsule())
                            .overlay(Capsule().stroke(m.mode == mode ? Theme.ink : .clear, lineWidth: 2.5))
                            .foregroundStyle(m.mode == mode ? Theme.paper : Theme.ink)
                    }
                }
            }
            .padding(5).inkCapsule()

            if m.isRunning {
                Button { m.startStop() } label: {
                    Label("Ferma", systemImage: "stop.fill")
                        .font(.system(.subheadline, design: .rounded).weight(.heavy))
                        .padding(.horizontal, 24).padding(.vertical, 10)
                        .inkCapsule()
                }
            } else {
                Text("Play/Pausa sugli AirPods = parla / smetti")
                    .font(.system(.caption, design: .rounded).weight(.semibold)).opacity(0.55)
            }
        }
    }
}

// MARK: - Impostazioni

struct SettingsView: View {
    @EnvironmentObject var m: WalkieModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Stanza"), footer: Text("Per internet usa un codice lungo e segreto: è anche la chiave di cifratura.")) {
                    TextField("Codice stanza", text: $m.room)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().disabled(m.isRunning)
                }
                Section(header: Text("Collegamento")) {
                    Picker("Collegamento", selection: $m.linkMode) {
                        ForEach(LinkMode.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).disabled(m.isRunning)
                    TextField("Relay internet", text: $m.relayURL)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.URL).disabled(m.isRunning)
                }
                if m.mode == .vox {
                    Section(header: Text("Attivazione a voce")) {
                        HStack { Text("Soglia"); Slider(value: $m.voxThreshold, in: 0.02...0.5) }
                    }
                }
                Section(header: Text("Audio")) {
                    Toggle("Alta qualità AirPods (sperimentale, iOS 26)", isOn: $m.highQuality).disabled(m.isRunning)
                }
                Section(header: Text("Isolamento vocale")) {
                    Text("Con Roger avviato apri il Centro di Controllo, tocca «Modalità microfono» e scegli «Isolamento vocale». Riduce il rumore del vento e del motore sulla tua voce.")
                        .font(.footnote).foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.cream)
            .tint(Theme.clay)
            .foregroundStyle(Theme.ink)
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() }.fontWeight(.heavy) } }
        }
        .preferredColorScheme(.light)
    }
}
