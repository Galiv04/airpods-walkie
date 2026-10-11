import SwiftUI

struct ContentView: View {
    @EnvironmentObject var m: WalkieModel

    var body: some View {
        VStack(spacing: 20) {
            header
            Spacer()
            talkButton
            Spacer()
            controls
        }
        .padding()
    }

    private var status: (text: String, color: Color) {
        (m.statusText, !m.isRunning ? .gray : (m.linked ? .green : .orange))
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text("Walkie").font(.largeTitle.bold())
            HStack { Circle().fill(status.color).frame(width: 10, height: 10); Text(status.text) }
            if m.isRunning { Text("Uscita: \(m.outputName)").font(.footnote).foregroundStyle(.secondary) }
            if m.remoteTalking { Text("🔊 L'altro sta parlando").font(.headline).foregroundStyle(.green) }
            if let e = m.error { Text(e).font(.footnote).foregroundStyle(.red) }
        }
    }

    private var talkButton: some View {
        let on = m.talking
        return ZStack {
            Circle().fill(on ? Color.red : Color.blue.opacity(0.8))
                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 4))
                .scaleEffect(on ? 1.0 + CGFloat(m.level) * 0.15 : 1)
                .animation(.easeOut(duration: 0.1), value: m.level)
            Text(label).font(.title.bold()).multilineTextAlignment(.center)
        }
        .frame(width: 240, height: 240)
        .opacity(m.isRunning ? 1 : 0.4)
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { _ in if m.mode == .pushToTalk && !m.talking { m.pttChanged(pressed: true) } }
            .onEnded { _ in
                if m.mode == .pushToTalk { m.pttChanged(pressed: false) }
                else if m.mode == .latch { m.pttChanged(pressed: true) }
            })
    }

    private var label: String {
        switch m.mode {
        case .pushToTalk: return m.talking ? "PARLI" : "TIENI\nPREMUTO"
        case .latch: return m.talking ? "PARLI\n(tocca per finire)" : "TOCCA\nPER PARLARE"
        case .vox: return m.talking ? "PARLI" : "Ascolto\nvoce…"
        }
    }

    private var controls: some View {
        VStack(spacing: 14) {
            Picker("Modo", selection: $m.mode) {
                ForEach(TalkMode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)

            if m.mode == .vox {
                HStack { Text("Soglia voce"); Slider(value: $m.voxThreshold, in: 0.02...0.5) }
            }
            Picker("Collegamento", selection: $m.linkMode) {
                ForEach(LinkMode.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).disabled(m.isRunning)
            DisclosureGroup("Impostazioni") {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Relay internet (es. xxx.workers.dev)", text: $m.relayURL)
                        .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                        .autocorrectionDisabled().keyboardType(.URL).disabled(m.isRunning)
                    Toggle("Alta qualità AirPods (sperimentale, iOS 26)", isOn: $m.highQuality).disabled(m.isRunning)
                    Text("Per internet usa un codice stanza lungo e segreto: è anche la chiave di cifratura.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(.top, 6)
            }
            HStack {
                Text("Stanza")
                TextField("codice", text: $m.room)
                    .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never)
                    .autocorrectionDisabled().disabled(m.isRunning)
            }
            HStack {
                Button(m.isRunning ? "Ferma" : "Avvia") { m.startStop() }
                    .buttonStyle(.borderedProminent).tint(m.isRunning ? .red : .green)
                Button("Isolamento voce") { m.showMicModes() }.buttonStyle(.bordered)
            }
            Text("Play/Pausa sugli AirPods = parla/smetti.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
