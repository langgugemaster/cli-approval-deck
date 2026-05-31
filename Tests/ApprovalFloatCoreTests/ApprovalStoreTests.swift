import Foundation
import Testing
@testable import ApprovalFloatCore

@Test func loadsPendingAndWritesResponse() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let pending = PendingApproval(
        requestId: "abc",
        command: "codex",
        prompt: "Allow command?",
        options: [ApprovalOption(key: "1", label: "Allow")],
        createdAt: "2026-05-30T00:00:00Z"
    )
    let data = try JSONEncoder().encode(pending)
    try data.write(to: directory.appendingPathComponent("pending.json"))

    let store = ApprovalStore(directory: directory)
    #expect(try store.loadPending() == pending)
    try store.submit(pending.options[0], for: pending)
    let response = try String(
        contentsOf: directory.appendingPathComponent("response-abc.txt"),
        encoding: .utf8
    )
    #expect(response == "1")
}

@Test func missingPendingReturnsNil() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    let store = ApprovalStore(directory: directory)
    #expect(try store.loadPending() == nil)
}
