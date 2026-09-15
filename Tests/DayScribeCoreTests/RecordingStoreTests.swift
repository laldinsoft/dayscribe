import XCTest
@testable import DayScribeCore

final class RecordingStoreTests: XCTestCase {
    func testRecoveryAndCollisionPreserveEveryByte() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = RecordingStore(pendingDirectory: root.appendingPathComponent("pending"), failedDirectory: root.appendingPathComponent("failed"))
        let recording = try store.newRecording(at: Date())
        let audio = Data([0, 1, 2, 3, 4])
        try audio.write(to: recording)
        XCTAssertEqual(try store.pendingRecordings().map { $0.resolvingSymlinksInPath() }, [recording.resolvingSymlinksInPath()])
        let first = try store.preserve(recording)
        try audio.write(to: recording)
        let second = try store.preserve(recording)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(try Data(contentsOf: first), audio)
        XCTAssertEqual(try Data(contentsOf: second), audio)
        XCTAssertTrue(try store.pendingRecordings().isEmpty)
    }

    func testFailedMoveLeavesOriginalAudio() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let failed = root.appendingPathComponent("failed")
        let store = RecordingStore(pendingDirectory: root.appendingPathComponent("pending"), failedDirectory: failed)
        let recording = try store.newRecording(at: Date())
        try Data([42]).write(to: recording)
        try Data([1]).write(to: failed)
        XCTAssertThrowsError(try store.preserve(recording))
        XCTAssertEqual(try Data(contentsOf: recording), Data([42]))
    }
}
