import Foundation

final class CodexUsageClient: @unchecked Sendable {
    private let timeout: TimeInterval
    private let fileManager: FileManager

    init(timeout: TimeInterval = 15, fileManager: FileManager = .default) {
        self.timeout = timeout
        self.fileManager = fileManager
    }

    func fetch() async throws -> UsageSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    continuation.resume(returning: try self.fetchSynchronously())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchSynchronously() throws -> UsageSnapshot {
        guard let codexURL = locateCodex() else {
            throw CodexUsageError.codexNotFound
        }

        let process = Process()
        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let state = ResponseState()
        let completed = DispatchSemaphore(value: 0)

        process.executableURL = codexURL
        process.arguments = ["app-server", "--stdio"]
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError
        process.environment = environmentForGUIApp()

        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            let action = state.consume(data)
            if action.shouldSendUsageRequests {
                Self.writeRequests(to: standardInput.fileHandleForWriting)
            }
            if action.didComplete {
                completed.signal()
            }
        }

        do {
            try process.run()
        } catch {
            standardOutput.fileHandleForReading.readabilityHandler = nil
            throw CodexUsageError.launchFailed(error.localizedDescription)
        }

        Self.writeInitialize(to: standardInput.fileHandleForWriting)
        let waitResult = completed.wait(timeout: .now() + timeout)

        standardOutput.fileHandleForReading.readabilityHandler = nil
        try? standardInput.fileHandleForWriting.close()
        if process.isRunning {
            process.terminate()
        }

        if waitResult == .timedOut {
            if let serverError = state.serverError {
                throw CodexUsageError.server(serverError)
            }
            throw CodexUsageError.timedOut
        }

        if let serverError = state.serverError {
            throw CodexUsageError.server(serverError)
        }
        guard let rateLimits = state.rateLimits, let usage = state.usage else {
            throw CodexUsageError.invalidResponse
        }
        return try CodexProtocolParser.makeSnapshot(
            rateLimitsResult: rateLimits,
            usageResult: usage
        )
    }

    private func locateCodex() -> URL? {
        var candidates: [String] = []
        if let configuredPath = ProcessInfo.processInfo.environment["CODEX_PATH"] {
            candidates.append(configuredPath)
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        candidates.append(contentsOf: [
            "\(home)/.local/bin/codex",
            "\(home)/.codex/packages/standalone/current/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ])

        return candidates
            .map(URL.init(fileURLWithPath:))
            .first { fileManager.isExecutableFile(atPath: $0.path) }
    }

    private func environmentForGUIApp() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let home = fileManager.homeDirectoryForCurrentUser.path
        let usefulPaths = [
            "\(home)/.local/bin",
            "\(home)/.codex/packages/standalone/current/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        environment["PATH"] = usefulPaths.joined(separator: ":")
        return environment
    }

    private static func writeInitialize(to handle: FileHandle) {
        writeJSON([
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "codex-meter",
                    "title": "Codex Meter",
                    "version": "0.1.0"
                ]
            ]
        ], to: handle)
    }

    private static func writeRequests(to handle: FileHandle) {
        writeJSON(["method": "initialized"], to: handle)
        writeJSON([
            "id": 2,
            "method": "account/rateLimits/read",
            "params": NSNull()
        ], to: handle)
        writeJSON([
            "id": 3,
            "method": "account/usage/read",
            "params": NSNull()
        ], to: handle)
    }

    private static func writeJSON(_ object: [String: Any], to handle: FileHandle) {
        guard var data = try? JSONSerialization.data(withJSONObject: object) else { return }
        data.append(0x0A)
        try? handle.write(contentsOf: data)
    }
}

private final class ResponseState {
    struct Action {
        var shouldSendUsageRequests = false
        var didComplete = false
    }

    private let lock = NSLock()
    private var buffer = Data()
    private var initialized = false
    private var completionSignaled = false
    private(set) var rateLimits: [String: Any]?
    private(set) var usage: [String: Any]?
    private(set) var serverError: String?

    func consume(_ data: Data) -> Action {
        lock.lock()
        defer { lock.unlock() }

        buffer.append(data)
        var action = Action()

        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard
                !line.isEmpty,
                let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any]
            else { continue }

            let id = (object["id"] as? NSNumber)?.intValue ?? object["id"] as? Int
            if id == 1, object["result"] != nil, !initialized {
                initialized = true
                action.shouldSendUsageRequests = true
            }

            if let error = object["error"] as? [String: Any], let message = error["message"] as? String {
                serverError = message
            }

            if id == 2, let result = object["result"] as? [String: Any] {
                rateLimits = result
            } else if id == 3, let result = object["result"] as? [String: Any] {
                usage = result
            }
        }

        if rateLimits != nil, usage != nil, !completionSignaled {
            completionSignaled = true
            action.didComplete = true
        }
        return action
    }
}
