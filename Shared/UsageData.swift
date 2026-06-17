import Foundation

/// usage.json lives here, written by the launchd helper. The sandboxed widget
/// reads it via a scoped temporary-exception entitlement for this path.
let usageRelativePath = "Library/Application Support/ClaudeUsageWidget/usage.json"

/// The user's REAL home directory. `NSHomeDirectory()` returns the sandbox
/// container path inside an app/extension, so resolve the real home directly.
func realHomeDirectory() -> String {
    if let pw = getpwuid(getuid()) {
        return String(cString: pw.pointee.pw_dir)
    }
    return NSHomeDirectory()
}

/// One usage bucket (e.g. the 5-hour session window or the weekly window).
struct UsageBlock: Codable, Hashable {
    let percent: Int
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case percent
        case resetsAt = "resets_at"
    }

    /// Parsed reset date, if present.
    var resetDate: Date? {
        guard let resetsAt else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: resetsAt) ?? ISO8601DateFormatter().date(from: resetsAt)
    }
}

/// The normalized payload the helper writes to the App Group container.
struct UsageData: Codable, Hashable {
    let updatedAt: Int
    let fiveHour: UsageBlock?
    let weekly: UsageBlock?
    let weeklyOpus: UsageBlock?
    let weeklySonnet: UsageBlock?
    let ok: Bool
    let error: String?

    enum CodingKeys: String, CodingKey {
        case updatedAt = "updated_at"
        case fiveHour = "five_hour"
        case weekly
        case weeklyOpus = "weekly_opus"
        case weeklySonnet = "weekly_sonnet"
        case ok
        case error
    }

    /// Placeholder used by the widget gallery and before the first read.
    static let placeholder = UsageData(
        updatedAt: 0,
        fiveHour: UsageBlock(percent: 24, resetsAt: nil),
        weekly: UsageBlock(percent: 5, resetsAt: nil),
        weeklyOpus: nil,
        weeklySonnet: UsageBlock(percent: 0, resetsAt: nil),
        ok: true,
        error: nil
    )

    /// Reads usage.json from the helper's output folder.
    static func load() -> UsageData? {
        let url = URL(fileURLWithPath: realHomeDirectory())
            .appendingPathComponent(usageRelativePath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(UsageData.self, from: data)
    }
}

/// Always a relative countdown so you can tell at a glance how far off a reset
/// is: "resets in 45m", "resets in 2h 14m", "resets in 6d 4h".
func resetLabel(_ block: UsageBlock?, now: Date = Date()) -> String {
    guard let date = block?.resetDate else { return "" }
    let interval = Int(date.timeIntervalSince(now))
    if interval <= 0 { return "resetting now" }
    let days = interval / 86_400
    let hours = (interval % 86_400) / 3600
    let mins = (interval % 3600) / 60
    let span: String
    if days > 0 {
        span = "\(days)d \(hours)h"
    } else if hours > 0 {
        span = "\(hours)h \(mins)m"
    } else {
        span = "\(mins)m"
    }
    return "resets in \(span)"
}
