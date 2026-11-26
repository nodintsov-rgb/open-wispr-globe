import AppKit

enum GlobeWelcome {
    static func showOnFirstLaunch() {
        let key = "GlobeEdition.didShowWelcomeWithWebsite"
        guard Bundle.main.bundleURL.pathExtension == "app",
              !UserDefaults.standard.bool(forKey: key) else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString(
            "welcome.title", tableName: "GlobeWelcome",
            value: "Welcome to OpenWispr Globe", comment: "First-launch title"
        )
        alert.informativeText = NSLocalizedString(
            "welcome.body", tableName: "GlobeWelcome",
            value: "Globe is an easy way to use local speech recognition powered by Whisper. Select a model under Model in the menu bar and wait for it to download. Then hold the Globe key and speak. Release the key to insert your text.\n\nEnjoy!\nNikita Odintsov",
            comment: "First-launch instructions and author credit"
        )
        let url = URL(string: "https://ATHEYA.org")!
        let website = NSTextView(frame: NSRect(x: 0, y: 0, width: 240, height: 22))
        website.isEditable = false
        website.isSelectable = true
        website.drawsBackground = false
        website.textContainerInset = .zero
        website.textContainer?.lineFragmentPadding = 0
        website.textStorage?.setAttributedString(NSAttributedString(
            string: url.absoluteString,
            attributes: [.link: url, .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
        ))
        alert.accessoryView = website
        alert.addButton(withTitle: NSLocalizedString(
            "welcome.continue", tableName: "GlobeWelcome",
            value: "Get started", comment: "Dismiss the welcome and continue setup"
        ))
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        UserDefaults.standard.set(true, forKey: key)
    }
}
