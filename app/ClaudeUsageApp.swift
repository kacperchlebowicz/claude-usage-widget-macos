import SwiftUI
import WidgetKit

@main
struct ClaudeUsageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 360, height: 280)
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    @State private var usage = UsageData.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Claude Usage", systemImage: "gauge.with.dots.needle.50percent")
                .font(.title2.weight(.semibold))

            if let u = usage, u.ok {
                row("5-hour session", u.fiveHour)
                row("Weekly", u.weekly)
                if let s = u.weeklySonnet { row("Weekly · Sonnet", s) }
                if let o = u.weeklyOpus { row("Weekly · Opus", o) }
                Text("Updated \(Date(timeIntervalSince1970: TimeInterval(u.updatedAt)).formatted(date: .omitted, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text(usage?.error ?? "No data yet. Make sure the helper LaunchAgent is installed (run install.sh).")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Spacer()

            HStack {
                Button("Refresh") { reload() }
                Spacer()
                Text("Add the widget from the desktop widget gallery.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .onAppear {
            // Force the desktop widget to re-render with the latest build/data
            // whenever the app is opened, so updates show without re-adding it.
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func row(_ title: String, _ block: UsageBlock?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(block?.percent ?? 0)%").monospacedDigit().bold()
            Text(resetLabel(block)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func reload() {
        usage = UsageData.load()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
