import Foundation
import Darwin

public struct NotesWriter: Sendable {
    public let directory: URL
    private let timeZone: TimeZone?

    public init(directory: URL, timeZone: TimeZone? = nil) {
        self.directory = directory
        self.timeZone = timeZone
    }

    private func formatted(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone ?? .current
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    public func fileURL(for date: Date) -> URL {
        directory.appendingPathComponent(formatted(date, "yyyy-MM-dd") + ".md")
    }

    public func ensureDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
    }

    @discardableResult
    public func ensureFile(for date: Date) throws -> URL {
        try write(text: nil, timestamp: date)
    }

    @discardableResult
    public func append(text: String, timestamp: Date) throws -> URL {
        let clean = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { throw DayScribeError.emptyTranscript }
        return try write(text: clean, timestamp: timestamp)
    }

    private func write(text: String?, timestamp: Date) throws -> URL {
        try ensureDirectory()
        let url = fileURL(for: timestamp)
        let fd = open(url.path, O_RDWR | O_CREAT | O_APPEND | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw systemError(url) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw systemError(url) }
        defer { flock(fd, LOCK_UN) }
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw systemError(url) }
        guard (info.st_mode & S_IFMT) == S_IFREG else {
            throw DayScribeError.message("The notes path is not a regular file: \(url.path)")
        }
        var addition = ""
        if info.st_size == 0 {
            addition = "# Notes - \(formatted(timestamp, "yyyy-MM-dd"))\n\n"
        } else if text != nil {
            var tail = [UInt8](repeating: 0, count: Int(min(2, info.st_size)))
            let count = tail.count
            guard pread(fd, &tail, count, info.st_size - off_t(count)) == count else {
                throw systemError(url)
            }
            if tail.last != 10 { addition = "\n\n" }
            else if count < 2 || tail[count - 2] != 10 { addition = "\n" }
        }
        if let text { addition += "[\(formatted(timestamp, "HH:mm:ss"))] \(text)\n\n" }
        guard !addition.isEmpty else { return url }
        do {
            try Data(addition.utf8).withUnsafeBytes { bytes in
                var written = 0
                while written < bytes.count {
                    let result = Darwin.write(fd, bytes.baseAddress!.advanced(by: written), bytes.count - written)
                    if result < 0 && errno == EINTR { continue }
                    guard result > 0 else { throw systemError(url) }
                    written += result
                }
            }
            guard fsync(fd) == 0 else { throw systemError(url) }
        } catch {
            // Restore the original length after a failed/partial append, where possible.
            _ = ftruncate(fd, info.st_size)
            _ = fsync(fd)
            throw error
        }
        return url
    }

    private func systemError(_ url: URL) -> Error {
        NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: url.path])
    }
}
