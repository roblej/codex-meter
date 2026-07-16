import Foundation

enum CodexProtocolParser {
    static func makeSnapshot(
        rateLimitsResult: [String: Any],
        usageResult: [String: Any],
        now: Date = Date(),
        calendar: Calendar? = nil
    ) throws -> UsageSnapshot {
        guard
            let rateLimit = preferredRateLimit(in: rateLimitsResult),
            let primary = rateLimit["primary"] as? [String: Any],
            let usedPercent = integer(primary["usedPercent"])
        else {
            throw CodexUsageError.invalidResponse
        }

        let summary = usageResult["summary"] as? [String: Any] ?? [:]
        let dailyRows = usageResult["dailyUsageBuckets"] as? [[String: Any]] ?? []
        let dailyUsage = dailyRows.compactMap { row -> UsageSnapshot.DailyUsage? in
            guard
                let startDate = row["startDate"] as? String,
                let tokens = int64(row["tokens"])
            else { return nil }
            return .init(startDate: startDate, tokens: tokens)
        }
        .sorted { $0.startDate < $1.startDate }

        let usageCalendar = calendar ?? accountUsageCalendar()
        let todayKey = dateKey(for: now, calendar: usageCalendar)
        let todayTokens = dailyUsage.first(where: { $0.startDate == todayKey })?.tokens ?? 0

        return UsageSnapshot(
            usedPercent: min(100, max(0, usedPercent)),
            windowDurationMinutes: int64(primary["windowDurationMins"]),
            resetsAt: int64(primary["resetsAt"]).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            planType: rateLimit["planType"] as? String,
            todayTokens: todayTokens,
            lifetimeTokens: int64(summary["lifetimeTokens"]),
            currentStreakDays: int64(summary["currentStreakDays"]),
            dailyUsage: Array(dailyUsage.suffix(14))
        )
    }

    private static func preferredRateLimit(in result: [String: Any]) -> [String: Any]? {
        if
            let buckets = result["rateLimitsByLimitId"] as? [String: Any],
            let codex = buckets["codex"] as? [String: Any]
        {
            return codex
        }
        return result["rateLimits"] as? [String: Any]
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private static func accountUsageCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
