import AppKit
import Foundation

func runInstaller(checkOnly: Bool, output: Pipe? = nil) throws -> (status: Int32, message: String) {
    guard let script = Bundle.main.url(forResource: "install-globe", withExtension: "sh") else {
        throw CocoaError(.fileNoSuchFile)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [script.path] + (checkOnly ? ["--check"] : [])
    if let output {
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
    }

    try process.run()
    let data = output?.fileHandleForReading.readDataToEndOfFile() ?? Data()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

if CommandLine.arguments.dropFirst().elementsEqual(["--check"]) {
    do {
        exit(try runInstaller(checkOnly: true).status)
    } catch {
        fputs("Проверка установщика: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

let progress = NSAlert()
progress.messageText = "Установка OpenWispr Globe"
progress.informativeText = "Подготавливаем whisper.cpp и копируем приложение. Это может занять несколько минут."
let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 24, height: 24))
spinner.style = .spinning
spinner.startAnimation(nil)
progress.accessoryView = spinner
progress.addButton(withTitle: "Подождите").isEnabled = false
progress.window.standardWindowButton(.closeButton)?.isEnabled = false

DispatchQueue.global(qos: .userInitiated).async {
    let result: (status: Int32, message: String)
    do {
        result = try runInstaller(checkOnly: false, output: Pipe())
    } catch {
        result = (1, error.localizedDescription)
    }

    DispatchQueue.main.async {
        NSApp.stopModal()
        progress.window.orderOut(nil)

        switch result.status {
        case 0:
            break
        case 20:
            let alert = NSAlert()
            alert.messageText = "Для установки нужен Homebrew"
            alert.informativeText = "Установите Homebrew по официальной инструкции, затем снова откройте установщик OpenWispr Globe."
            alert.addButton(withTitle: "Открыть инструкцию")
            alert.addButton(withTitle: "Закрыть")
            if alert.runModal() == .alertFirstButtonReturn,
               let url = URL(string: "https://brew.sh/") {
                NSWorkspace.shared.open(url)
            }
        default:
            let alert = NSAlert()
            alert.alertStyle = result.status == 21 ? .informational : .warning
            alert.messageText = result.status == 21
                ? "OpenWispr Globe установлен"
                : "Установку OpenWispr Globe не удалось завершить"
            let details = result.message.split(separator: "\n").suffix(10).joined(separator: "\n")
            alert.informativeText = details.isEmpty ? "Код завершения \(result.status)." : details
            alert.addButton(withTitle: "Закрыть")
            alert.runModal()
        }

        exit(result.status == 21 ? 0 : result.status)
    }
}
progress.runModal()
RunLoop.main.run()
