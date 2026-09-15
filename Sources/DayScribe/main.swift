import AppKit
import DayScribeCore

// Developer smoke test: run real inference without touching the microphone or notes.
if CommandLine.arguments.count == 2 && ["--enable-login", "--disable-login", "--login-status"].contains(CommandLine.arguments[1]) {
    MainActor.assumeIsolated {
        do {
            switch CommandLine.arguments[1] {
            case "--enable-login": try LoginItemManager.setEnabled(true)
            case "--disable-login": try LoginItemManager.setEnabled(false)
            default: break
            }
            print("Launch at Login: \(LoginItemManager.statusDescription)")
        } catch {
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
} else if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--transcribe" {
    let file = URL(fileURLWithPath: CommandLine.arguments[2])
    Task {
        let service = WhisperTranscriptionService(model: modelURL())
        do {
            let start = Date()
            try await service.prepare()
            let loaded = Date()
            let text = try await service.transcribe(file: file)
            let finished = Date()
            await service.shutdown()
            print(text)
            let timings = String(format: "Model load: %.2fs; transcription: %.2fs\n", loaded.timeIntervalSince(start), finished.timeIntervalSince(loaded))
            FileHandle.standardError.write(Data(timings.utf8))
            exit(0)
        } catch {
            await service.shutdown()
            FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
    dispatchMain()
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
