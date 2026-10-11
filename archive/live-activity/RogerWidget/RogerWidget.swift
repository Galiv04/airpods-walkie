import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

@main
struct RogerWidgetBundle: WidgetBundle {
    var body: some Widget { RogerLiveActivity() }
}

private let clay = Color(red: 0.851, green: 0.467, blue: 0.341)
private let cream = Color(red: 0.953, green: 0.925, blue: 0.878)
private let ink = Color(red: 0.110, green: 0.094, blue: 0.086)
private let sky = Color(red: 0.478, green: 0.667, blue: 0.784)
private let green = Color(red: 0.40, green: 0.66, blue: 0.42)

private typealias State = RogerAttributes.ContentState

private func color(_ s: State) -> Color {
    switch s.phase {
    case "talking": return clay
    case "remote": return sky
    case "linked", "echo": return green
    default: return .gray
    }
}

private func icon(_ s: State) -> String {
    switch s.phase {
    case "talking": return "mic.fill"
    case "remote": return "waveform"
    case "linked", "echo": return "antenna.radiowaves.left.and.right"
    default: return "antenna.radiowaves.left.and.right.slash"
    }
}

private func title(_ s: State) -> String {
    let who = s.partner.isEmpty ? "l'altro" : s.partner
    switch s.phase {
    case "talking": return "Stai parlando"
    case "remote": return "\(s.partner.isEmpty ? "L'altro" : s.partner) parla"
    case "linked": return "Collegato con \(who)"
    case "echo": return "Test eco"
    default: return "In attesa di \(who)"
    }
}

private func subtitle(_ s: State) -> String {
    switch s.phase {
    case "waiting": return "Roger è acceso"
    case "echo": return "Parla e ti risenti"
    default: return s.viaInternet ? "via internet" : "collegamento diretto"
    }
}

private struct Badge: View {
    let state: State
    var body: some View {
        Image(systemName: icon(state))
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color(state))
    }
}

private struct Clock: View {
    let state: State
    var body: some View {
        Text(timerInterval: state.since...Date.distantFuture, countsDown: false)
            .monospacedDigit()
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(color(state))
            .frame(maxWidth: 46)
    }
}

@available(iOS 17.0, *)
private struct TalkButton: View {
    let state: State
    var body: some View {
        Button(intent: ToggleTalkIntent()) {
            Label(state.phase == "talking" ? "Chiudi" : "Parla",
                  systemImage: state.phase == "talking" ? "stop.fill" : "mic.fill")
                .font(.system(.subheadline, design: .rounded).weight(.heavy))
        }
        .tint(state.phase == "talking" ? ink : clay)
        .disabled(state.phase == "waiting")
    }
}

private struct LockScreenView: View {
    let state: State
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color(state)).frame(width: 44, height: 44)
                Circle().stroke(ink, lineWidth: 2.5).frame(width: 44, height: 44)
                Image(systemName: icon(state)).font(.system(size: 19, weight: .bold)).foregroundStyle(cream)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title(state)).font(.system(.headline, design: .rounded).weight(.heavy)).foregroundStyle(ink)
                Text(subtitle(state)).font(.system(.caption, design: .rounded)).foregroundStyle(ink.opacity(0.65))
            }
            Spacer()
            if #available(iOS 17.0, *) {
                TalkButton(state: state)
            } else {
                Text("Roger").font(.system(.headline, design: .rounded).weight(.black)).foregroundStyle(ink)
            }
        }
        .padding(16)
    }
}

struct RogerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RogerAttributes.self) { ctx in
            LockScreenView(state: ctx.state)
                .activityBackgroundTint(cream)
                .activitySystemActionForegroundColor(ink)
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Badge(state: ctx.state).font(.title2).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if ctx.state.phase == "talking" || ctx.state.phase == "remote" { Clock(state: ctx.state) }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(ctx.state)).font(.system(.headline, design: .rounded).weight(.heavy)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(subtitle(ctx.state)).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        if #available(iOS 17.0, *) { TalkButton(state: ctx.state) }
                    }
                }
            } compactLeading: {
                Badge(state: ctx.state)
            } compactTrailing: {
                if ctx.state.phase == "talking" || ctx.state.phase == "remote" {
                    Clock(state: ctx.state)
                } else {
                    Text(ctx.state.phase == "waiting" ? "…" : "OK")
                        .font(.system(.caption, design: .rounded).weight(.heavy))
                        .foregroundStyle(color(ctx.state))
                }
            } minimal: {
                Badge(state: ctx.state)
            }
            .keylineTint(clay)
        }
    }
}
