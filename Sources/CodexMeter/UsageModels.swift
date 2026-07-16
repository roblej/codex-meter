import Foundation

struct UsageSnapshot: Equatable, Sendable {
    struct DailyUsage: Equatable, Identifiable, Sendable {
        let startDate: String
        let tokens: Int64

        var id: String { startDate }
    }

    let usedPercent: Int
    let windowDurationMinutes: Int64?
    let resetsAt: Date?
    let planType: String?
    let todayTokens: Int64
    let lifetimeTokens: Int64?
    let currentStreakDays: Int64?
    let dailyUsage: [DailyUsage]

    var remainingPercent: Int {
        max(0, 100 - usedPercent)
    }

    var windowLabel: String {
        guard let minutes = windowDurationMinutes else { return "사용 한도" }
        let days = minutes / (60 * 24)
        if days > 0 { return "\(days)일 한도" }
        let hours = minutes / 60
        if hours > 0 { return "\(hours)시간 한도" }
        return "\(minutes)분 한도"
    }
}

enum CodexUsageError: LocalizedError {
    case codexNotFound
    case launchFailed(String)
    case timedOut
    case server(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .codexNotFound:
            return "Codex CLI를 찾지 못했습니다. Codex 앱 또는 CLI 설치를 확인해 주세요."
        case .launchFailed(let message):
            return "Codex 사용량 조회를 시작하지 못했습니다: \(message)"
        case .timedOut:
            return "Codex 사용량 응답 시간이 초과되었습니다."
        case .server(let message):
            return "Codex가 오류를 반환했습니다: \(message)"
        case .invalidResponse:
            return "Codex 사용량 응답 형식을 해석하지 못했습니다."
        }
    }
}
