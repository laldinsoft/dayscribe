import AppKit
import DayScribeCore
import Darwin

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menu: MenuBarController!
    private var manager: RecordingManager!
    private var notifications: NotificationManager!
    private let shortcut = GlobalShortcutManager()
    private var instanceLock: Int32 = -1
    private var terminating = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = home.appendingPathComponent("Library/Application Support/DayScribe", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            instanceLock = open(support.appendingPathComponent("instance.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
            guard instanceLock >= 0 else { throw DayScribeError.message("Could not create the DayScribe instance lock.") }
            // A second process must never recover audio from an actively recording first process.
            guard flock(instanceLock, LOCK_EX | LOCK_NB) == 0 else { NSApp.terminate(nil); return }
        } catch {
            let alert = NSAlert()
            alert.messageText = "DayScribe could not start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let writer = NotesWriter(directory: home.appendingPathComponent("Documents/Dictation", isDirectory: true))
        let store = RecordingStore(pendingDirectory: support.appendingPathComponent("Pending", isDirectory: true),
                                   failedDirectory: writer.directory.appendingPathComponent("failed", isDirectory: true))
        notifications = NotificationManager()
        manager = RecordingManager(transcription: WhisperTranscriptionService(model: modelURL()),
            writer: writer, store: store, notifications: notifications)
        menu = MenuBarController()
        manager.onChange = { [weak self] in
            guard let self else { return }
            self.menu.update(state: self.manager.state, hasError: self.manager.lastError != nil)
        }
        menu.onToggle = { [weak self] in self?.manager.toggle() }
        shortcut.onPress = { [weak self] in self?.manager.toggle() }
        menu.onOpenToday = { [weak self] in
            do {
                let url = try writer.ensureFile(for: Date())
                guard NSWorkspace.shared.open(url) else { throw DayScribeError.message("No editor could open \(url.path). Choose a default Markdown editor in Finder.") }
            } catch { self?.manager.report(error.localizedDescription) }
        }
        menu.onOpenFolder = { [weak self] in
            do {
                try writer.ensureDirectory()
                guard NSWorkspace.shared.open(writer.directory) else { throw DayScribeError.message("Finder could not open the notes folder.") }
            } catch { self?.manager.report(error.localizedDescription) }
        }
        menu.onShowError = { [weak self] in
            guard let self, let message = self.manager.lastError else { return }
            self.notifications.showAlert(title: "DayScribe", message: message)
        }
        menu.onQuit = { NSApp.terminate(nil) }
        menu.onOpenMenu = { [weak self] in self?.refreshLoginItem() }
        menu.onToggleLogin = { [weak self] in
            guard let self else { return }
            if LoginItemManager.status == .requiresApproval {
                LoginItemManager.openSettings()
            } else {
                do { try LoginItemManager.setEnabled(LoginItemManager.status != .enabled) }
                catch { self.manager.report(error.localizedDescription) }
            }
            self.refreshLoginItem()
        }
        refreshLoginItem()
        do { try shortcut.register() }
        catch { manager.report(error.localizedDescription) }
        manager.prepare()
    }

    private func refreshLoginItem() {
        menu.updateLoginItem(enabled: LoginItemManager.status == .enabled,
                             requiresApproval: LoginItemManager.status == .requiresApproval)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminating { return .terminateLater }
        if manager?.isBusy == true { NSSound.beep(); return .terminateCancel }
        guard let manager else { return .terminateNow }
        terminating = true
        shortcut.unregister()
        Task {
            await manager.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcut.unregister()
        if instanceLock >= 0 { close(instanceLock) }
    }
}

func modelURL() -> URL {
    Bundle.main.resourceURL!.appendingPathComponent("ggml-small.en.bin")
}
