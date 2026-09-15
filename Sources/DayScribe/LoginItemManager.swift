import Foundation
import ServiceManagement
import DayScribeCore

@MainActor
enum LoginItemManager {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard status != .enabled else { return }
            guard status != .requiresApproval else {
                throw DayScribeError.message("Allow DayScribe in System Settings → General → Login Items & Extensions.")
            }
            try SMAppService.mainApp.register()
            guard status == .enabled else {
                throw DayScribeError.message("Launch at Login needs approval in System Settings → General → Login Items & Extensions.")
            }
        } else if status != .notRegistered {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }

    static var statusDescription: String {
        switch status {
        case .enabled: return "enabled"
        case .notRegistered: return "disabled"
        case .requiresApproval: return "requires approval in System Settings → General → Login Items & Extensions"
        case .notFound: return "unavailable; move DayScribe.app to Applications and reopen it"
        @unknown default: return "unknown"
        }
    }
}
