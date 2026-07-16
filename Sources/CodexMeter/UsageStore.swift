import Foundation

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastUpdated: Date?

    private let client: CodexUsageClient

    init(client: CodexUsageClient = CodexUsageClient()) {
        self.client = client
    }

    var menuIcon: String {
        if isLoading { return "arrow.triangle.2.circlepath" }
        if errorMessage != nil { return "exclamationmark.circle" }
        guard let used = snapshot?.usedPercent else { return "gauge.with.dots.needle.33percent" }
        switch used {
        case 80...: return "gauge.with.dots.needle.100percent"
        case 50...: return "gauge.with.dots.needle.67percent"
        default: return "gauge.with.dots.needle.33percent"
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            snapshot = try await client.fetch()
            lastUpdated = Date()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
