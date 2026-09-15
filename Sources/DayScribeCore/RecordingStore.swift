import Foundation

public struct RecordingStore: Sendable {
    public let pendingDirectory: URL
    public let failedDirectory: URL

    public init(pendingDirectory: URL, failedDirectory: URL) {
        self.pendingDirectory = pendingDirectory
        self.failedDirectory = failedDirectory
    }

    public func newRecording(at date: Date) throws -> URL {
        try FileManager.default.createDirectory(at: pendingDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return pendingDirectory.appendingPathComponent("\(formatter.string(from: date))-\(UUID().uuidString).wav")
    }

    @discardableResult
    public func preserve(_ recording: URL) throws -> URL {
        try FileManager.default.createDirectory(at: failedDirectory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        var destination = failedDirectory.appendingPathComponent(recording.lastPathComponent)
        if FileManager.default.fileExists(atPath: destination.path) {
            destination = failedDirectory.appendingPathComponent("\(recording.deletingPathExtension().lastPathComponent)-\(UUID().uuidString).wav")
        }
        try FileManager.default.moveItem(at: recording, to: destination)
        return destination
    }

    public func pendingRecordings() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: pendingDirectory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: pendingDirectory,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
            .filter {
                guard $0.pathExtension == "wav" else { return false }
                return try $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true
            }
    }
}
