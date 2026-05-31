import Foundation
import Testing
@testable import ApprovalFloatCore

@Test func loadsPendingAndWritesResponse() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let pendingDirectory = directory.appendingPathComponent("pending")
    try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
    let pending = PendingApproval(
        requestId: "abc",
        command: "codex",
        prompt: "Allow command?",
        options: [ApprovalOption(key: "1", label: "Allow")],
        createdAt: "2026-05-30T00:00:00Z"
    )
    let data = try JSONEncoder().encode(pending)
    try data.write(to: pendingDirectory.appendingPathComponent("abc.json"))

    let store = ApprovalStore(directory: directory)
    #expect(try store.loadPending() == [pending])
    try store.submit(pending.options[0], for: pending)
    let response = try String(
        contentsOf: directory.appendingPathComponent("response-abc.txt"),
        encoding: .utf8
    )
    #expect(response == "1")
}

@Test func missingPendingReturnsEmptyArray() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let store = ApprovalStore(directory: directory)
    #expect(try store.loadPending() == [])
}

@Test func loadsMultiplePendingRequestsOldestFirst() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let pendingDirectory = directory.appendingPathComponent("pending")
    try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true)
    let newer = PendingApproval(
        requestId: "newer",
        command: "claude",
        prompt: "Proceed?",
        options: [],
        createdAt: "2026-05-30T01:00:00Z"
    )
    let older = PendingApproval(
        requestId: "older",
        command: "codex",
        prompt: "Allow?",
        options: [],
        createdAt: "2026-05-30T00:00:00Z"
    )
    try JSONEncoder().encode(newer)
        .write(to: pendingDirectory.appendingPathComponent("newer.json"))
    try JSONEncoder().encode(older)
        .write(to: pendingDirectory.appendingPathComponent("older.json"))

    let store = ApprovalStore(directory: directory)
    #expect(try store.loadPending() == [older, newer])
}

@Test func approveOptionAlwaysUsesFirstMenuChoice() {
    let pending = PendingApproval(
        requestId: "abc",
        command: "codex",
        prompt: "Allow command?",
        options: [
            ApprovalOption(key: "2", label: "Allow for session"),
            ApprovalOption(key: "1", label: "Allow once"),
            ApprovalOption(key: "3", label: "Reject")
        ],
        createdAt: "2026-05-30T00:00:00Z"
    )

    #expect(pending.approveOption == ApprovalOption(key: "1", label: "Allow once"))
}
