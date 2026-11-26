import AppKit
import ServiceManagement

enum LaunchAtLogin {
    private static let promptKey = "GlobeEdition.didOfferLaunchAtLogin"
    private static var service: SMAppService { .mainApp }

    // Register only installed copies. A disk image or build folder may disappear.
    static var canRegister: Bool {
        let bundle = Bundle.main.bundleURL.resolvingSymlinksInPath()
        guard bundle.pathExtension == "app" else { return false }
        let parent = bundle.deletingLastPathComponent().path
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications").resolvingSymlinksInPath().path
        return parent == "/Applications" || parent == userApplications
    }

    static var status: SMAppService.Status { service.status }

    static func offerOnFirstLaunch() {
        guard canRegister, status == .notRegistered,
              !UserDefaults.standard.bool(forKey: promptKey) else { return }
        let alert = NSAlert()
        alert.messageText = "Запускать OpenWispr при входе?"
        alert.informativeText = "После входа в macOS OpenWispr появится в строке меню. Настройку можно изменить из меню приложения."
        alert.addButton(withTitle: "Включить автозапуск")
        alert.addButton(withTitle: "Не сейчас")
        NSApp.activate(ignoringOtherApps: true)
        let startAtLogin = alert.runModal() == .alertFirstButtonReturn
        UserDefaults.standard.set(true, forKey: promptKey)
        if startAtLogin { toggle() }
    }

    static func toggle() {
        guard canRegister else { return }
        do {
            switch status {
            case .enabled:
                try service.unregister()
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Не удалось изменить автозапуск OpenWispr"
            alert.addButton(withTitle: "Открыть настройки")
            alert.addButton(withTitle: "Закрыть")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                SMAppService.openSystemSettingsLoginItems()
            }
        }
    }
}
