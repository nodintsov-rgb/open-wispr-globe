import AppKit
import Foundation

let checkOnly = CommandLine.arguments.dropFirst().elementsEqual(["--check"])

func runInstaller() throws -> Int32 {
    guard let script = Bundle.main.url(forResource: "Install OpenWispr Globe", withExtension: "command") else {
        throw CocoaError(.fileNoSuchFile)
    }

    let process = Process()
    if checkOnly {
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "--check"]
    } else {
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-b", "com.apple.Terminal", script.path]
    }
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus
}

do {
    let status = try runInstaller()
    if status == 0 || checkOnly {
        exit(status)
    }
} catch {
    if checkOnly {
        fputs("Проверка установщика: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)
let alert = NSAlert()
alert.alertStyle = .warning
alert.messageText = "Не удалось открыть установщик OpenWispr"
alert.informativeText = "Откройте образ заново и повторите запуск. Для подтверждения установки используется Терминал macOS."
alert.addButton(withTitle: "Закрыть")
alert.runModal()
exit(1)
