import SwiftUI

private let cyan = Color(red: 0.27, green: 0.86, blue: 1.0)
private let pink = Color(red: 1.0, green: 0.35, blue: 0.63)

struct ContentView: View {
    @EnvironmentObject var m: WalkieModel
    @State private var showSettings = false
    @State private var breathe = false

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                topBar
                statusBlock.padding(.top, 8)
                Spacer(minLength: 12)
                mainButton
                Spacer(minLength: 12)
                bottomBar
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(m)
        }
        .onAppear { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { breathe = true } }
    }

    // MARK: Sfondo

    private var accent: Color { m.talking ? pink : (m.remoteTalking ? .green : cyan) }

    private var background: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.04, green: 0.05, blue: 0.15), Color(red: 0.2, green: 0.08, blue: 0.36)],
                           startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [accent.opacity(m.isRunning ? 0.28 : 0.1), .clear],
                           center: .center, startRadius: 10, endRadius: 360)
                .animation(.easeInOut(duration: 0.4), value: m.talking)
                .animation(.easeInOut(duration: 0.4), value: m.remoteTalking)
        }.ignoresSafeArea()
    }

    // MARK: Barra in alto

    private var topBar: some View {
        HStack {
            Button { showSettings = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "person.2.wave.2.fill")
                    Text(m.room.isEmpty ? "Stanza" : m.room).lineLimit(1)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(.white.opacity(0.1), in: Capsule())
            }
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.1), in: Circle())
            }
        }
        .foregroundStyle(.white)
    }

    private var statusColor: Color { !m.isRunning ? .gray : (m.linked ? .green : .orange) }

    private var statusBlock: some View {
        VStack(spacing: 8) {
            Text("WALKIE").font(.system(size: 15, weight: .heavy, design: .rounded)).tracking(6)
                .foregroundStyle(LinearGradient(colors: [cyan, pink], startPoint: .leading, endPoint: .trailing))
            HStack(spacing: 8) {
                Circle().fill(statusColor).frame(width: 9, height: 9)
                    .shadow(color: statusColor, radius: m.linked ? 5 : 0)
                Text(m.statusText).font(.headline)
            }
            if m.isRunning {
                Label(m.outputName, systemImage: "airpodspro").font(.footnote).foregroundStyle(.white.opacity(0.6))
            }
            if m.remoteTalking {
                Label("L'altro sta parlando", systemImage: "waveform").font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green).transition(.opacity)
            }
            if let e = m.error {
                Text(e).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
        }
        .foregroundStyle(.white)
        .animation(.easeInOut(duration: 0.2), value: m.remoteTalking)
    }

    // MARK: Pulsante centrale (Avvia / Parla)

    private var mainButton: some View {
        let lvl = CGFloat(min(1, m.level * 2))
        return ZStack {
            if m.isRunning {
                ForEach(0..<3) { i in
                    Circle().stroke(accent.opacity(0.35 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: 250 + CGFloat(i) * 46, height: 250 + CGFloat(i) * 46)
                        .scaleEffect((m.talking ? 1 + lvl * 0.12 : (breathe ? 1.03 : 0.98)))
                        .animation(.easeOut(duration: 0.12), value: m.level)
                }
            }
            Circle()
                .fill(LinearGradient(colors: m.isRunning ? (m.talking ? [pink, Color(red: 0.8, green: 0.15, blue: 0.4)] : [cyan, Color(red: 0.25, green: 0.4, blue: 0.95)])
                                                         : [Color.white.opacity(0.18), Color.white.opacity(0.08)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 2))
                .shadow(color: (m.isRunning ? accent : .clear).opacity(0.6), radius: m.talking ? 36 : 22)
                .frame(width: 236, height: 236)
                .scaleEffect(m.talking ? 1 + lvl * 0.05 : 1)
                .animation(.easeOut(duration: 0.1), value: m.level)
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: 54, weight: .semibold))
                Text(label).font(.headline.weight(.bold)).multilineTextAlignment(.center)
            }.foregroundStyle(.white)
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
        .animation(.easeInOut(duration: 0.25), value: m.talking)
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
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                ForEach(TalkMode.allCases) { mode in
                    Button { m.mode = mode } label: {
                        Text(mode.rawValue).font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(m.mode == mode ? Color.white.opacity(0.22) : .clear, in: Capsule())
                    }
                }
            }
            .padding(4).background(.white.opacity(0.08), in: Capsule()).foregroundStyle(.white)

            if m.isRunning {
                Button { m.startStop() } label: {
                    Label("Ferma", systemImage: "stop.fill").font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 22).padding(.vertical, 10)
                        .background(Color.red.opacity(0.25), in: Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.6), lineWidth: 1))
                }.foregroundStyle(.white)
            } else {
                Text("Play/Pausa sugli AirPods = parla / smetti").font(.caption).foregroundStyle(.white.opacity(0.5))
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
                    Text("Con Walkie avviato apri il Centro di Controllo, tocca «Modalità microfono» e scegli «Isolamento vocale». Riduce il rumore del vento e del motore sulla tua voce.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } } }
        }
    }
}
