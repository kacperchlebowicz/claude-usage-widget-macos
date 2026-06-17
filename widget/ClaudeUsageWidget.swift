import WidgetKit
import SwiftUI

// MARK: - Timeline

struct UsageEntry: TimelineEntry {
    let date: Date
    let usage: UsageData
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), usage: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(UsageEntry(date: Date(), usage: UsageData.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: Date(), usage: UsageData.load() ?? .placeholder)
        // The LaunchAgent refreshes usage.json every 5 min; re-read shortly after.
        let next = Calendar.current.date(byAdding: .minute, value: 10, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Bar

private func barColor(_ percent: Int) -> Color {
    switch percent {
    case ..<60: return .green
    case ..<85: return .orange
    default: return .red
    }
}

/// One usage window rendered as: label + big %, a progress bar, and a relative
/// reset countdown underneath. `large` boosts the type/bar for the small widget,
/// where the bars are the primary content.
struct UsageBar: View {
    let label: String
    let block: UsageBlock?
    var large = false

    var body: some View {
        let percent = block?.percent ?? 0
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(large ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                Spacer()
                Text("\(percent)%")
                    .font((large ? Font.title : Font.subheadline).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(barColor(percent))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(barColor(percent))
                        .frame(width: max(4, geo.size.width * min(Double(percent) / 100, 1)))
                }
            }
            .frame(height: large ? 11 : 7)
            Text(resetLabel(block))
                .font(large ? .caption : .caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Views

struct ClaudeUsageWidgetView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        let u = entry.usage
        let small = family == .systemSmall

        VStack(alignment: .leading, spacing: small ? 8 : 11) {
            // Small cloud mark + a quiet label, roughly the size of the reset text.
            HStack(spacing: 4) {
                Image(systemName: "cloud.fill")
                    .foregroundStyle(.orange)
                Text("Token usage")
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .font((small ? Font.caption2 : Font.caption).weight(.semibold))

            if u.ok {
                // Bars grouped tighter than the icon→bars gap above.
                VStack(alignment: .leading, spacing: small ? 3 : 8) {
                    UsageBar(label: "5-hour", block: u.fiveHour, large: small)
                    UsageBar(label: "Weekly", block: u.weekly, large: small)

                    if !small, u.weeklyOpus != nil || u.weeklySonnet != nil {
                        HStack(spacing: 10) {
                            if let o = u.weeklyOpus {
                                Text("Opus \(o.percent)%")
                            }
                            if let s = u.weeklySonnet {
                                Text("Sonnet \(s.percent)%")
                            }
                            Spacer()
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("⚠︎ \(u.error ?? "no data yet")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        // Pin to the top so the bars sit high and the leftover space falls to the
        // bottom — gives an even top/sides margin with a slightly larger bottom.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

// MARK: - Widget

@main
struct ClaudeUsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ClaudeUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Your 5-hour session and weekly usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        // Manage our own padding instead of WidgetKit's large default margins,
        // so the layout sits as tight as the Battery/Weather widgets.
        .contentMarginsDisabled()
    }
}
