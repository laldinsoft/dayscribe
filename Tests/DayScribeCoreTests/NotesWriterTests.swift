import XCTest
@testable import DayScribeCore

final class NotesWriterTests: XCTestCase {
    private var root: URL!
    private var writer: NotesWriter!
    private let utc = TimeZone(secondsFromGMT: 0)!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        writer = NotesWriter(directory: root.appendingPathComponent("notes"), timeZone: utc)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    func testFirstNoteAndAppendHaveOneHeader() throws {
        let first = date("2026-09-15T10:17:42Z")
        let file = try writer.append(text: "First note.", timestamp: first)
        try writer.append(text: "Second note.", timestamp: date("2026-09-15T11:36:08Z"))
        XCTAssertEqual(file.lastPathComponent, "2026-09-15.md")
        XCTAssertEqual(try String(contentsOf: file), "# Notes - 2026-09-15\n\n[10:17:42] First note.\n\n[11:36:08] Second note.\n\n")
    }

    func testExistingEditedFileIsNeverRewritten() throws {
        let now = date("2026-09-15T10:17:42Z")
        try writer.ensureDirectory()
        let url = writer.fileURL(for: now)
        try "My own heading\nExisting note without newline".write(to: url, atomically: true, encoding: .utf8)
        try writer.append(text: "New note.", timestamp: now)
        XCTAssertEqual(try String(contentsOf: url), "My own heading\nExisting note without newline\n\n[10:17:42] New note.\n\n")
    }

    func testOpenTodayIsIdempotent() throws {
        let now = date("2026-09-15T10:17:42Z")
        let file = try writer.ensureFile(for: now)
        try writer.ensureFile(for: now)
        XCTAssertEqual(try String(contentsOf: file), "# Notes - 2026-09-15\n\n")
    }

    func testParagraphsAndUnicodeSurvive() throws {
        let file = try writer.append(text: "  First — café.\r\n\r\nSecond paragraph.\n", timestamp: date("2026-09-15T10:17:42Z"))
        XCTAssertTrue(try String(contentsOf: file).contains("First — café.\n\nSecond paragraph.\n\n"))
    }

    func testEmptyTranscriptDoesNotCreateNotes() throws {
        XCTAssertThrowsError(try writer.append(text: " \n\t", timestamp: Date()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: writer.directory.path))
    }

    func testMidnightUsesSuppliedRecordingTime() throws {
        let first = try writer.append(text: "Before midnight", timestamp: date("2026-09-15T23:59:59Z"))
        let second = try writer.append(text: "After midnight", timestamp: date("2026-09-16T00:00:01Z"))
        XCTAssertEqual(first.lastPathComponent, "2026-09-15.md")
        XCTAssertEqual(second.lastPathComponent, "2026-09-16.md")
    }

    func testLocalTimeZoneControlsBothDateAndTimestamp() throws {
        let local = NotesWriter(directory: writer.directory, timeZone: TimeZone(identifier: "Europe/London")!)
        let file = try local.append(text: "British summer time", timestamp: date("2026-09-15T23:17:42Z"))
        XCTAssertEqual(file.lastPathComponent, "2026-09-16.md")
        XCTAssertTrue(try String(contentsOf: file).contains("[00:17:42]"))
    }

    func testConcurrentAppendsDoNotLoseEntries() async throws {
        let writer = self.writer!
        let now = date("2026-09-15T10:17:42Z")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<40 { group.addTask { _ = try writer.append(text: "Entry \(i).", timestamp: now) } }
            try await group.waitForAll()
        }
        let text = try String(contentsOf: writer.fileURL(for: now))
        XCTAssertEqual(text.components(separatedBy: "# Notes - ").count - 1, 1)
        for i in 0..<40 { XCTAssertEqual(text.components(separatedBy: "[10:17:42] Entry \(i).\n\n").count - 1, 1) }
    }

    func testInvalidDirectoryThrowsWithoutOverwritingBlocker() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "keep me".write(to: writer.directory, atomically: true, encoding: .utf8)
        XCTAssertThrowsError(try writer.append(text: "note", timestamp: Date()))
        XCTAssertEqual(try String(contentsOf: writer.directory), "keep me")
    }

    func testSymlinkDoesNotOverwriteAnotherFile() throws {
        try writer.ensureDirectory()
        let target = root.appendingPathComponent("other.md")
        try "untouched".write(to: target, atomically: true, encoding: .utf8)
        let now = Date()
        try FileManager.default.createSymbolicLink(at: writer.fileURL(for: now), withDestinationURL: target)
        XCTAssertThrowsError(try writer.append(text: "note", timestamp: now))
        XCTAssertEqual(try String(contentsOf: target), "untouched")
    }
}
