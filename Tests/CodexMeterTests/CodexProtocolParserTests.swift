import XCTest
@testable import CodexMeter

final class CodexProtocolParserTests: XCTestCase {
    func testBuildsSnapshotFromCodexBucket() throws {
        let rateLimits: [String: Any] = [
            "rateLimits": ["primary": ["usedPercent": 99]],
            "rateLimitsByLimitId": [
                "codex": [
                    "primary": [
                        "usedPercent": 6,
                        "windowDurationMins": 10_080,
                        "resetsAt": 1_784_780_875
                    ],
                    "planType": "plus"
                ]
            ]
        ]
        let usage: [String: Any] = [
            "summary": [
                "lifetimeTokens": 4_395_658,
                "currentStreakDays": 3
            ],
            "dailyUsageBuckets": [
                ["startDate": "2026-07-15", "tokens": 1_000],
                ["startDate": "2026-07-16", "tokens": 2_000]
            ]
        ]

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let now = calendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 16,
            hour: 12
        ))!
        let snapshot = try CodexProtocolParser.makeSnapshot(
            rateLimitsResult: rateLimits,
            usageResult: usage,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(snapshot.usedPercent, 6)
        XCTAssertEqual(snapshot.remainingPercent, 94)
        XCTAssertEqual(snapshot.windowLabel, "7일 한도")
        XCTAssertEqual(snapshot.planType, "plus")
        XCTAssertEqual(snapshot.todayTokens, 2_000)
        XCTAssertEqual(snapshot.lifetimeTokens, 4_395_658)
        XCTAssertEqual(snapshot.currentStreakDays, 3)
        XCTAssertEqual(snapshot.dailyUsage.count, 2)
    }

    func testUsesPacificDateForAccountDailyUsageByDefault() throws {
        let rateLimits: [String: Any] = [
            "rateLimits": [
                "primary": ["usedPercent": 16]
            ]
        ]
        let usage: [String: Any] = [
            "dailyUsageBuckets": [
                ["startDate": "2026-07-15", "tokens": 3_967_187],
                ["startDate": "2026-07-16", "tokens": 100]
            ]
        ]

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = utcCalendar.date(from: DateComponents(
            year: 2026,
            month: 7,
            day: 16,
            hour: 6,
            minute: 30
        ))!

        let snapshot = try CodexProtocolParser.makeSnapshot(
            rateLimitsResult: rateLimits,
            usageResult: usage,
            now: now
        )

        XCTAssertEqual(snapshot.todayTokens, 3_967_187)
    }

    func testRejectsMissingPrimaryWindow() {
        XCTAssertThrowsError(
            try CodexProtocolParser.makeSnapshot(
                rateLimitsResult: ["rateLimits": [:]],
                usageResult: [:]
            )
        )
    }
}
