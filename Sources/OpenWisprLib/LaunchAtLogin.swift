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
        guard canRegister, status != .enabled,
              !UserDefaults.standard.bool(forKey: promptKey) else { return }
        let alert = NSAlert()
        alert.messageText = "Запускать OpenWispr при входе?"
        alert.informativeText = "После входа в macOS OpenWispr появится в строке меню. Настройку можно изменить из меню приложения."
        alert.addButton(withTitle: "Включить автозапуск")
        alert.addButton(withTitle: "Не сейчас")
        NSApp.activate(ignoringOtherApps: true)
        let startAtLogin = alert.runModal() == .alertFirstButtonReturn
        UserDefaults.standard.set(true, forKey: promptKey)
        if startAtLogin { enable() }
    }

    static func toggle() {
        guard canRegister else {
            let alert = NSAlert()
            alert.messageText = "Откройте установленный OpenWispr"
            alert.informativeText = "Для автозапуска откройте OpenWispr из папки «Программы» в Finder."
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        guard status == .enabled else {
            enable()
            return
        }
        do {
            try service.unregister()
        } catch {
            showRegistrationError(error)
        }
    }

    private static func enable() {
        do {
            switch status {
            case .enabled:
                return
            case .requiresApproval:
                SMAppService.openSystemSettingsLoginItems()
            default:
                try service.register()
                if status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                }
            }
        } catch {
            showRegistrationError(error)
        }
    }

    private static func showRegistrationError(_ error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Не удалось изменить автозапуск OpenWispr"
        alert.informativeText = error.localizedDescription
        alert.addButton(withTitle: "Открыть настройки")
        alert.addButton(withTitle: "Закрыть")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
