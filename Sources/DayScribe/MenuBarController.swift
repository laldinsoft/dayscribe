import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let title = NSMenuItem(title: "DayScribe", action: nil, keyEquivalent: "")
    private let record = NSMenuItem(title: "Start Recording", action: nil, keyEquivalent: "")
    private let errorItem = NSMenuItem(title: "Show Last Error…", action: nil, keyEquivalent: "")
    private let quit = NSMenuItem(title: "Quit DayScribe", action: nil, keyEquivalent: "q")
    private let login = NSMenuItem(title: "Launch at Login", action: nil, keyEquivalent: "")
    var onToggle: (() -> Void)?
    var onOpenToday: (() -> Void)?
    var onOpenFolder: (() -> Void)?
    var onShowError: (() -> Void)?
    var onQuit: (() -> Void)?
    var onToggleLogin: (() -> Void)?
    var onOpenMenu: (() -> Void)?

    override init() {
        super.init()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        record.target = self
        record.action = #selector(toggle)
        // The Carbon registration handles the shortcut, including when this menu is closed.
        record.title = "Start Recording  ⌃⌥N"
        menu.addItem(record)
        let today = NSMenuItem(title: "Open Today’s Notes", action: #selector(openToday), keyEquivalent: "")
        today.target = self
        menu.addItem(today)
        let folder = NSMenuItem(title: "Open Notes Folder", action: #selector(openFolder), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)
        errorItem.target = self
        errorItem.action = #selector(showError)
        errorItem.isHidden = true
        menu.addItem(errorItem)
        menu.addItem(.separator())
        login.target = self
        login.action = #selector(toggleLogin)
        menu.addItem(login)
        quit.target = self
        quit.action = #selector(quitApp)
        menu.addItem(quit)
        item.menu = menu
        update(state: .loading, hasError: false)
    }

    func updateLoginItem(enabled: Bool, requiresApproval: Bool) {
        login.state = enabled ? .on : (requiresApproval ? .mixed : .off)
        login.title = requiresApproval ? "Launch at Login — Approval Needed…" : "Launch at Login"
    }

    func menuWillOpen(_ menu: NSMenu) { onOpenMenu?() }

    func update(state: RecordingState, hasError: Bool) {
        let label: String
        let symbol: String
        switch state {
        case .loading: label = "Loading local model…"; symbol = "hourglass"
        case .idle: label = "Ready"; symbol = "mic"
        case .requestingPermission: label = "Waiting for microphone…"; symbol = "mic.badge.plus"
        case .recording: label = "Recording…"; symbol = "record.circle.fill"
        case .transcribing: label = "Transcribing…"; symbol = "ellipsis.circle"
        case .error: label = "Needs attention"; symbol = "exclamationmark.triangle"
        }
        title.title = "DayScribe — \(label)"
        item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DayScribe: \(label)")
        item.button?.contentTintColor = state == .recording ? .systemRed : nil
        item.button?.toolTip = "DayScribe: \(label) · Control–Option–N"
        item.button?.setAccessibilityLabel("DayScribe: \(label)")
        record.title = state == .recording ? "Stop Recording  ⌃⌥N" : "Start Recording  ⌃⌥N"
        record.isEnabled = [.idle, .error, .recording].contains(state)
        quit.isEnabled = [.idle, .error].contains(state)
        quit.toolTip = quit.isEnabled ? nil : "Finish recording and transcription before quitting."
        errorItem.isHidden = !hasError
    }

    @objc private func toggle() { onToggle?() }
    @objc private func openToday() { onOpenToday?() }
    @objc private func openFolder() { onOpenFolder?() }
    @objc private func showError() { onShowError?() }
    @objc private func quitApp() { onQuit?() }
    @objc private func toggleLogin() { onToggleLogin?() }
}
