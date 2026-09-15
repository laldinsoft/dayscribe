import AVFoundation
import DayScribeCore
import Foundation

@MainActor
final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    var onUnexpectedStop: ((Error) -> Void)?

    func start(at url: URL) throws {
        let recorder = try AVAudioRecorder(url: url, settings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ])
        recorder.delegate = self
        guard recorder.prepareToRecord() else {
            throw DayScribeError.message("The microphone could not prepare a recording.")
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        guard recorder.record() else {
            throw DayScribeError.message("The microphone could not start. Check that an input device is connected.")
        }
        self.recorder = recorder
    }

    func stop() {
        recorder?.delegate = nil
        recorder?.stop()
        recorder = nil
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let message = error?.localizedDescription ?? "The microphone stopped unexpectedly."
        Task { @MainActor [weak self] in
            self?.onUnexpectedStop?(DayScribeError.message(message))
        }
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor [weak self] in
            self?.onUnexpectedStop?(DayScribeError.message("The microphone recording was interrupted."))
        }
    }
}
