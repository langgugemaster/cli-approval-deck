import Foundation

public struct ApprovalOption: Codable, Equatable {
    public let key: String
    public let label: String

    public init(key: String, label: String) {
        self.key = key
        self.label = label
    }
}

public struct PendingApproval: Codable, Equatable {
    public let requestId: String
    public let command: String
    public let prompt: String
    public let options: [ApprovalOption]
    public let createdAt: String

    public init(
        requestId: String,
        command: String,
        prompt: String,
        options: [ApprovalOption],
        createdAt: String
    ) {
        self.requestId = requestId
        self.command = command
        self.prompt = prompt
        self.options = options
        self.createdAt = createdAt
    }
}

public final class ApprovalStore {
    public let directory: URL
    private let fileManager: FileManager
    private let decoder = JSONDecoder()

    public init(
        directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cli-approval-float", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func loadPending() throws -> [PendingApproval] {
        let pendingDirectory = directory.appendingPathComponent("pending", isDirectory: true)
        guard fileManager.fileExists(atPath: pendingDirectory.path) else {
            return []
        }
        let urls = try fileManager.contentsOfDirectory(
            at: pendingDirectory,
            includingPropertiesForKeys: nil
        )
        return try urls
            .filter { $0.pathExtension == "json" }
            .map { try decoder.decode(PendingApproval.self, from: Data(contentsOf: $0)) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func submit(_ option: ApprovalOption, for approval: PendingApproval) throws {
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let responseURL = directory
            .appendingPathComponent("response-\(approval.requestId).txt")
        try Data(option.key.utf8).write(to: responseURL, options: .atomic)
    }
}
