import AppKit
import Darwin
import Foundation

let openWisprIdentifier = "com.human37.open-wispr"
let openWisprAppName = "OpenWispr Globe Universal.app"

func isGlobeCopyOnInternalDisk(_ url: URL) -> Bool {
    guard let values = try? url.resourceValues(forKeys: [.isSymbolicLinkKey, .volumeIsInternalKey]),
          values.isSymbolicLink == false, values.volumeIsInternal == true,
          !url.resolvingSymlinksInPath().path.hasPrefix("/Volumes/"),
          Bundle(url: url)?.bundleIdentifier == openWisprIdentifier else { return false }
    return checkSignature(url)
}

func checkSignature(_ url: URL) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
    process.arguments = ["--verify", "--deep", "--strict", url.path]
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
}

func offerLegacyCleanup(except installed: URL) {
    let manager = FileManager.default
    let folders = [URL(fileURLWithPath: "/Applications"),
                   manager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
    let candidates = folders.flatMap {
        (try? manager.contentsOfDirectory(at: $0, includingPropertiesForKeys: [.isSymbolicLinkKey, .volumeIsInternalKey],
                                          options: [.skipsHiddenFiles])) ?? []
    }.filter { url in
        url.resolvingSymlinksInPath().path != installed.resolvingSymlinksInPath().path &&
        (url.lastPathComponent == openWisprAppName ||
         url.lastPathComponent.range(of: #"^OpenWispr Globe [0-9]+\.[0-9]+\.[0-9]+-globe\.[0-9]+(?: Universal|-[0-9]{8}-[0-9]{6})?\.app$"#,
                                     options: .regularExpression) != nil) &&
        isGlobeCopyOnInternalDisk(url)
    }
    guard !candidates.isEmpty else { return }

    let alert = NSAlert()
    alert.messageText = "Убрать прежние копии OpenWispr Globe?"
    alert.informativeText = candidates.map(\.path).joined(separator: "\n")
    alert.addButton(withTitle: "Переместить в Корзину")
    alert.addButton(withTitle: "Оставить")
    NSApp.activate(ignoringOtherApps: true)
    guard alert.runModal() == .alertFirstButtonReturn else { return }

    let running = NSRunningApplication.runningApplications(withBundleIdentifier: openWisprIdentifier)
    let runningPaths = Set(running.filter { !$0.isTerminated }.compactMap { $0.bundleURL?.resolvingSymlinksInPath().path })
    let failed = candidates.filter { url in
        guard !runningPaths.contains(url.resolvingSymlinksInPath().path), isGlobeCopyOnInternalDisk(url) else { return true }
        do {
            try manager.trashItem(at: url, resultingItemURL: nil)
            return false
        } catch {
            return true
        }
    }
    if let first = failed.first {
        showInstalledApp(first, message: "Некоторые прежние копии остались",
                         details: "Закройте их и переместите в Корзину через Finder.")
    }
}

func replaceInstalledApp(_ url: URL) throws {
    let manager = FileManager.default
    guard url.lastPathComponent == openWisprAppName,
          isGlobeCopyOnInternalDisk(url),
          let source = Bundle.main.url(forResource: "OpenWispr Globe Universal", withExtension: "app") else {
        throw CocoaError(.fileWriteNoPermission)
    }
    let temporary = url.deletingLastPathComponent().appendingPathComponent(".OpenWispr-\(UUID().uuidString).app")
    do {
        try manager.copyItem(at: source, to: temporary)
        guard checkSignature(temporary) else { throw CocoaError(.fileReadCorruptFile) }
        guard renameatx_np(AT_FDCWD, temporary.path, AT_FDCWD, url.path, UInt32(RENAME_SWAP)) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
    } catch {
        try? manager.removeItem(at: temporary)
        throw error
    }
    do {
        try manager.trashItem(at: temporary, resultingItemURL: nil)
    } catch {
        showInstalledApp(temporary, message: "Старая копия осталась в папке «Программы»",
                         details: "Новое приложение установлено. Старую копию можно убрать через Finder.")
    }
}

func showInstalledApp(_ url: URL, message: String, details: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = details
    alert.addButton(withTitle: "Показать в Finder")
    alert.addButton(withTitle: "Закрыть")
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertFirstButtonReturn {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

func openInstalledApp(_ url: URL, replacing: Bool = false) {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: openWisprIdentifier)
        .filter { !$0.isTerminated }
    let installedPath = url.resolvingSymlinksInPath().path
    let previous = running.filter { replacing || $0.bundleURL?.resolvingSymlinksInPath().path != installedPath }

    if replacing || !previous.isEmpty {
        let alert = NSAlert()
        alert.messageText = replacing ? "Заменить установленный OpenWispr Globe?" : "Переключиться на установленный OpenWispr Globe?"
        alert.informativeText = replacing
            ? "Прежняя копия по этому пути будет перемещена в Корзину. Завершите текущую диктовку перед заменой. Модели и настройки останутся на месте."
            : "Сейчас открыта другая копия. Завершите текущую диктовку, затем нажмите «Закрыть и открыть новую». Если нужно, macOS запросит разрешение на запуск."
        alert.addButton(withTitle: replacing ? "Заменить и открыть" : "Закрыть и открыть новую")
        alert.addButton(withTitle: "Позже")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { exit(0) }

        previous.forEach { _ = $0.terminate() }
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        while previous.contains(where: { !$0.isTerminated }),
              ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        let remaining = NSRunningApplication.runningApplications(withBundleIdentifier: openWisprIdentifier)
            .contains { !$0.isTerminated && (replacing || $0.bundleURL?.resolvingSymlinksInPath().path != installedPath) }
        if remaining {
            showInstalledApp(
                url,
                message: "Другая копия OpenWispr ещё работает",
                details: "Закройте её через Quit в строке меню. Затем откройте установленную копию из Finder."
            )
            exit(0)
        }
    }

    if replacing {
        do {
            try replaceInstalledApp(url)
        } catch {
            showInstalledApp(url, message: "Не удалось заменить приложение", details: error.localizedDescription)
            exit(1)
        }
    }

    offerLegacyCleanup(except: url)

    if running.contains(where: { !$0.isTerminated && $0.bundleURL?.resolvingSymlinksInPath().path == installedPath }) {
        showInstalledApp(
            url,
            message: "OpenWispr Globe уже открыт",
            details: "Значок диктовки и пункт «Запускать при входе» находятся в строке меню macOS."
        )
        exit(0)
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.createsNewApplicationInstance = true
    NSWorkspace.shared.openApplication(at: url, configuration: configuration) { launchedApp, error in
        DispatchQueue.main.async {
            if launchedApp == nil || error != nil {
                showInstalledApp(
                    url,
                    message: "OpenWispr Globe установлен",
                    details: "Если macOS заблокировала запуск, разрешите запуск OpenWispr Globe в разделе «Конфиденциальность и безопасность». Открыть установленную копию повторно можно из Finder."
                )
            }
            exit(0)
        }
    }
}

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
progress.informativeText = "Копируем OpenWispr Globe Universal со встроенным движком распознавания."
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
        case 0, 22:
            let parts = result.message.components(separatedBy: "\0")
            if parts.count == 3, parts[1].hasPrefix("/") {
                openInstalledApp(URL(fileURLWithPath: parts[1], isDirectory: true), replacing: result.status == 22)
                return
            }
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Не удалось определить путь к установленному OpenWispr Globe"
            alert.addButton(withTitle: "Закрыть")
            alert.runModal()
            exit(1)
        default:
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Установку OpenWispr Globe не удалось завершить"
            let details = result.message.split(separator: "\n").suffix(10).joined(separator: "\n")
            alert.informativeText = details.isEmpty ? "Код завершения \(result.status)." : details
            alert.addButton(withTitle: "Закрыть")
            alert.runModal()
        }

        exit(result.status)
    }
}
progress.runModal()
RunLoop.main.run()
