import AVFoundation
import DayScribeCore
import Foundation

enum RecordingState: Equatable {
    case loading, idle, requestingPermission, recording, transcribing, error
}

@MainActor
final class RecordingManager {
    private(set) var state: RecordingState = .loading { didSet { onChange?() } }
    private(set) var lastError: String? { didSet { onChange?() } }
    var onChange: (() -> Void)?
    private let recorder = AudioRecorder()
    private let transcription: any TranscriptionService
    private let writer: NotesWriter
    private let store: RecordingStore
    private let notifications: NotificationManager
    private var recordingURL: URL?
    private var startedAt: Date?
    private var operation: Task<Void, Never>?

    var isBusy: Bool { [.loading, .requestingPermission, .recording, .transcribing].contains(state) }
    var canToggle: Bool { [.idle, .error, .recording].contains(state) }

    init(transcription: any TranscriptionService, writer: NotesWriter,
         store: RecordingStore, notifications: NotificationManager) {
        self.transcription = transcription
        self.writer = writer
        self.store = store
        self.notifications = notifications
        recorder.onUnexpectedStop = { [weak self] error in
            guard let self, self.state == .recording else { return }
            self.recorder.stop()
            self.fail(error, recording: self.recordingURL)
        }
    }

    func prepare() {
        operation = Task {
            do {
                let pending = try store.pendingRecordings()
                for file in pending { try store.preserve(file) }
                if !pending.isEmpty {
                    report("Recovered \(pending.count) interrupted recording(s). Audio is in \(store.failedDirectory.path). Review it manually; it may already have been written to your notes before the interruption.")
                }
                try await transcription.prepare()
                state = .idle
            } catch { fail(error, recording: nil) }
        }
    }

    func toggle() {
        switch state {
        case .idle, .error: start()
        case .recording: stopAndTranscribe()
        case .loading, .requestingPermission, .transcribing: break
        }
    }

    private func start() {
        state = .requestingPermission
        operation = Task {
            let allowed: Bool
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: allowed = true
            case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .audio)
            default: allowed = false
            }
            guard allowed else {
                fail(DayScribeError.message("Allow DayScribe in System Settings → Privacy & Security → Microphone, then try again."), recording: nil)
                return
            }
            do {
                let date = Date()
                let url = try store.newRecording(at: date)
                recordingURL = url
                startedAt = date
                try recorder.start(at: url)
                lastError = nil
                state = .recording
            } catch { fail(error, recording: recordingURL) }
        }
    }

    private func stopAndTranscribe() {
        recorder.stop()
        guard let url = recordingURL, let timestamp = startedAt else { return }
        state = .transcribing
        operation = Task {
            do {
                let text = try await transcription.transcribe(file: url)
                let writer = self.writer
                _ = try await Task.detached(priority: .userInitiated) {
                    try writer.append(text: text, timestamp: timestamp)
                }.value
            } catch {
                fail(error, recording: url)
                return
            }
            // Only delete audio after the durable Markdown append has succeeded.
            do { try FileManager.default.removeItem(at: url) }
            catch {
                report("Your note was saved, but its temporary audio could not be deleted. Remove it manually from \(url.path). \(error.localizedDescription)")
            }
            recordingURL = nil
            startedAt = nil
            state = .idle
        }
    }

    private func fail(_ error: Error, recording: URL?) {
        recorder.stop()
        var message = error.localizedDescription
        if let recording, FileManager.default.fileExists(atPath: recording.path) {
            do {
                let preserved = try store.preserve(recording)
                message += "\n\nThe audio recording has been saved:\n\(preserved.path)"
            } catch {
                message += "\n\nThe audio is still at:\n\(recording.path)\nIt could not be moved: \(error.localizedDescription)"
            }
        }
        recordingURL = nil
        startedAt = nil
        state = .error
        report(message)
    }

    func report(_ message: String) {
        lastError = message
        notifications.report(title: "DayScribe needs attention", message: message)
    }

    func shutdown() async {
        state = .loading // Disable recording while releasing the Metal context.
        await transcription.shutdown()
    }
}
