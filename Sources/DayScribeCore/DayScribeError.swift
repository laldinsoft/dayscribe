import Foundation

public enum DayScribeError: LocalizedError {
    case message(String)
    case emptyTranscript
    public var errorDescription: String? {
        switch self {
        case .message(let message): return message
        case .emptyTranscript: return "No speech was recognized. The recording has been kept for recovery."
        }
    }
}
