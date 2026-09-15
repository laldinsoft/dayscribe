import AVFoundation
import Foundation
import WhisperBridge

public protocol TranscriptionService: Sendable {
    func prepare() async throws
    func transcribe(file: URL) async throws -> String
    func shutdown() async
}

// One actor owns the resident context; inference never runs on the UI actor.
public actor WhisperTranscriptionService: TranscriptionService {
    private let model: URL
    private var context: UnsafeMutableRawPointer?

    public init(model: URL) { self.model = model }
    deinit { if let context { ds_whisper_destroy(context) } }

    public func shutdown() {
        if let context { ds_whisper_destroy(context) }
        context = nil
    }

    public func prepare() throws {
        guard context == nil else { return }
        guard FileManager.default.isReadableFile(atPath: model.path) else {
            throw DayScribeError.message("The local Whisper model is missing. Rebuild DayScribe using scripts/build.sh. Expected: \(model.path)")
        }
        context = ds_whisper_create(model.path)
        guard context != nil else {
            throw DayScribeError.message("Whisper could not load the local model. Check available memory and rebuild if the model is damaged.")
        }
    }

    public func transcribe(file: URL) throws -> String {
        try prepare()
        let audio = try AVAudioFile(forReading: file, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard audio.processingFormat.sampleRate == 16_000, audio.processingFormat.channelCount == 1,
              audio.length > 0, audio.length <= Int64(Int32.max),
              let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat, frameCapacity: AVAudioFrameCount(audio.length)) else {
            throw DayScribeError.message("The recording must contain 16 kHz mono audio.")
        }
        try audio.read(into: buffer)
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength >= 1600 else {
            throw DayScribeError.emptyTranscript
        }
        // Silence must not turn into a fabricated Whisper phrase.
        let count = Int(buffer.frameLength)
        var energy: Double = 0
        for i in 0..<count { energy += Double(samples[i]) * Double(samples[i]) }
        guard sqrt(energy / Double(count)) > 0.0001 else { throw DayScribeError.emptyTranscript }
        guard let output = ds_whisper_transcribe(context, samples, Int32(count)) else {
            throw DayScribeError.message("Local speech recognition failed.")
        }
        defer { ds_whisper_free_text(output) }
        let text = String(cString: output).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw DayScribeError.emptyTranscript }
        return text
    }
}
