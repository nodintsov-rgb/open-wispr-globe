import AppKit

public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: StatusBarController!
    var hotkeyManagers: [HotkeyManager] = []
    var recorder: AudioRecorder!
    var transcriber: Transcriber!
    var inserter: TextInserter!
    var config: Config!
    var recordingLifecycle = RecordingLifecycle()
    private let recordingSoundFeedback = RecordingSoundFeedback()
    var currentRecordingURL: URL?
    private var sleepWakeObservers: [NSObjectProtocol] = []
    private var permissionPollTimer: Timer?
    var isReady = false
    public var lastTranscription: String?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController()
        recorder = AudioRecorder()
        registerSleepWakeObservers()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            GlobeWelcome.showOnFirstLaunch()
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.setup()
            }
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        permissionPollTimer?.invalidate()
        recorder?.teardown()
        unregisterSleepWakeObservers()
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        switch statusBar?.state {
        case .waitingForMicrophone:
            Permissions.openMicrophoneSettings()
        case .waitingForPermission:
            Permissions.openAccessibilitySettings()
        default:
            break
        }
        return false
    }

    private func setup() {
        config = Config.load()
        inserter = TextInserter()
        migrateAudioDeviceUIDIfNeeded()
        recorder.preferredDeviceID = AudioDeviceManager.resolveConfiguredDeviceID(
            uid: config.audioInputDeviceUID,
            legacyID: config.audioInputDeviceID
        )
        recorder.voiceProcessingEnabled = config.isVoiceProcessingEnabled
        if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
            RecordingStore.deleteAllRecordings()
        }
        transcriber = makeTranscriber(for: config)

        DispatchQueue.main.async {
            self.statusBar.reprocessHandler = { [weak self] url in
                self?.reprocess(audioURL: url)
            }
            self.statusBar.onConfigChange = { [weak self] newConfig in
                self?.applyConfigChange(newConfig)
            }
            self.statusBar.buildMenu()
        }

        if Transcriber.findWhisperBinary() == nil {
            print("Error: whisper-cpp not found. Install it with: brew install whisper-cpp")
            DispatchQueue.main.async { [weak self] in
                self?.statusBar.state = .error("whisper-cpp не найден. Откройте установщик OpenWispr Globe.")
                self?.statusBar.buildMenu()
            }
            return
        }

        let didUpgrade = Permissions.didUpgrade()
        if Permissions.shouldResetAccessibility(afterUpgrade: didUpgrade, isTrusted: AXIsProcessTrusted()) {
            print("Accessibility: version changed and permission is not granted; resetting stale entry...")
            if Permissions.resetAccessibility() {
                Permissions.recordCurrentVersion()
                Thread.sleep(forTimeInterval: 1)
            } else {
                print("Accessibility: reset failed; toggle OpenWispr OFF, then ON in System Settings")
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.beginMicrophoneStep()
        }
    }

    private func beginMicrophoneStep() {
        if Permissions.microphoneGranted {
            beginAccessibilityStep()
            return
        }

        statusBar.state = .waitingForMicrophone
        statusBar.buildMenu()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            if Permissions.microphoneGranted {
                self?.beginAccessibilityStep()
            }
        }

        Permissions.requestMicrophone { [weak self] granted in
            guard let self, case .waitingForMicrophone = self.statusBar.state else { return }
            if granted || Permissions.microphoneGranted {
                self.beginAccessibilityStep()
            } else {
                let alert = NSAlert()
                alert.messageText = "Разрешите OpenWispr доступ к микрофону"
                alert.informativeText = "Включите OpenWispr в разделе «Конфиденциальность и безопасность → Микрофон». Если macOS предложит завершить работу и открыть приложение снова, подтвердите."
                alert.addButton(withTitle: "Открыть настройки микрофона")
                alert.addButton(withTitle: "Закрыть")
                NSApp.activate(ignoringOtherApps: true)
                if alert.runModal() == .alertFirstButtonReturn {
                    Permissions.openMicrophoneSettings()
                }
            }
        }
    }

    private func beginAccessibilityStep() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        if AXIsProcessTrusted() {
            resumeWhenAccessibilityGranted()
            return
        }

        statusBar.state = .waitingForPermission
        statusBar.buildMenu()
        Permissions.promptAccessibility()
        Permissions.openAccessibilitySettings()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.resumeWhenAccessibilityGranted()
        }
        resumeWhenAccessibilityGranted()
    }

    private func resumeWhenAccessibilityGranted() {
        guard AXIsProcessTrusted() else { return }
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        statusBar.state = .starting
        statusBar.buildMenu()
        print("Accessibility: granted")
        Permissions.recordCurrentVersion()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                try self.finishSetup()
            } catch {
                print("Fatal setup error: \(error.localizedDescription)")
                DispatchQueue.main.async { [weak self] in
                    self?.statusBar.state = .error(error.localizedDescription)
                    self?.statusBar.updateDownloadProgress(nil)
                }
            }
        }
    }

    private func finishSetup() throws {
        if !Transcriber.modelExists(modelSize: config.modelSize) {
            DispatchQueue.main.async {
                self.statusBar.state = .downloading
                self.statusBar.updateDownloadProgress("Downloading \(self.config.modelSize) model...")
            }
            print("Downloading \(config.modelSize) model...")
            try ModelDownloader.download(modelSize: config.modelSize) { [weak self] percent in
                DispatchQueue.main.async {
                    let pct = Int(percent)
                    self?.statusBar.updateDownloadProgress("Downloading \(self?.config.modelSize ?? "") model... \(pct)%", percent: percent)
                }
            }
            DispatchQueue.main.async {
                self.statusBar.updateDownloadProgress(nil)
            }
        }

        if let modelPath = Transcriber.findModel(modelSize: config.modelSize) {
            let modelURL = URL(fileURLWithPath: modelPath)
            if !ModelDownloader.isValidGGMLFile(at: modelURL) {
                let msg = "Model file is corrupted. Re-download with: open-wispr download-model \(config.modelSize)"
                print("Error: \(msg)")
                DispatchQueue.main.async {
                    self.statusBar.state = .error(msg)
                    self.statusBar.buildMenu()
                }
                return
            }
        }

        if config.isVADEnabled && Transcriber.findVADModel() == nil {
            DispatchQueue.main.async {
                self.statusBar.state = .downloading
                self.statusBar.updateDownloadProgress("Downloading voice activity model...")
            }
            try ModelDownloader.downloadVAD { [weak self] percent in
                DispatchQueue.main.async {
                    self?.statusBar.updateDownloadProgress("Downloading voice activity model... \(Int(percent))%", percent: percent)
                }
            }
            DispatchQueue.main.async { self.statusBar.updateDownloadProgress(nil) }
        }

        DispatchQueue.main.async { [weak self] in
            self?.startListening()
        }
    }

    private func startListening() {
        for m in hotkeyManagers { m.stop() }
        hotkeyManagers = []
        for hk in config.hotkeys {
            let manager = HotkeyManager(
                keyCode: hk.keyCode,
                modifiers: hk.modifierFlags,
                holdDelay: hk.keyCode == 63 && !(config.toggleMode?.value ?? false) ? 0.35 : 0
            )
            manager.start(
                onKeyDown: { [weak self] in
                    self?.handleKeyDown()
                },
                onKeyUp: { [weak self] in
                    self?.handleKeyUp()
                }
            )
            hotkeyManagers.append(manager)
        }

        isReady = true
        statusBar.state = .idle
        statusBar.buildMenu()

        let hotkeyDesc = config.hotkeySummary()
        print("open-wispr v\(OpenWispr.version)")
        print("Hotkey: \(hotkeyDesc)")
        print("Model: \(config.modelSize)")
        print("Ready.")
        print("Local Globe hold fix: 350 ms delay; duplicate Fn flags ignored.")
        recorder.prepare()
        LaunchAtLogin.offerOnFirstLaunch()
    }

    public func reloadConfig() {
        let newConfig = Config.load()
        applyConfigChange(newConfig)
    }

    /// Configs written by older versions store only the numeric AudioDeviceID,
    /// which is not stable across reboots or device replugs. If that ID still
    /// refers to a device, persist its UID so the selection survives.
    private func migrateAudioDeviceUIDIfNeeded() {
        guard config.audioInputDeviceUID == nil,
              let legacyID = config.audioInputDeviceID,
              let uid = AudioDeviceManager.getDeviceUID(deviceID: legacyID) else { return }
        config.audioInputDeviceUID = uid
        try? config.save()
    }

    func applyConfigChange(_ newConfig: Config) {
        guard isReady else { return }
        let wasDownloading: Bool
        if case .downloading = statusBar.state { wasDownloading = true } else { wasDownloading = false }
        let newDeviceID = AudioDeviceManager.resolveConfiguredDeviceID(
            uid: newConfig.audioInputDeviceUID,
            legacyID: newConfig.audioInputDeviceID
        )
        config = newConfig
        recorder.preferredDeviceID = newDeviceID
        recorder.voiceProcessingEnabled = config.isVoiceProcessingEnabled
        recorder.prepare()
        transcriber = makeTranscriber(for: config)
        inserter = TextInserter()

        for m in hotkeyManagers { m.stop() }
        hotkeyManagers = []
        for hk in config.hotkeys {
            let manager = HotkeyManager(
                keyCode: hk.keyCode,
                modifiers: hk.modifierFlags,
                holdDelay: hk.keyCode == 63 && !(config.toggleMode?.value ?? false) ? 0.35 : 0
            )
            manager.start(
                onKeyDown: { [weak self] in self?.handleKeyDown() },
                onKeyUp: { [weak self] in self?.handleKeyUp() }
            )
            hotkeyManagers.append(manager)
        }

        let needsWhisperModel = !Transcriber.modelExists(modelSize: config.modelSize)
        let needsVADModel = config.isVADEnabled && Transcriber.findVADModel() == nil
        if !wasDownloading && (needsWhisperModel || needsVADModel) {
            statusBar.state = .downloading
            statusBar.updateDownloadProgress(needsWhisperModel
                ? "Downloading \(config.modelSize) model..."
                : "Downloading voice activity model...")
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                do {
                    if needsWhisperModel {
                        try ModelDownloader.download(modelSize: newConfig.modelSize) { percent in
                            DispatchQueue.main.async {
                                self?.statusBar.updateDownloadProgress("Downloading \(newConfig.modelSize) model... \(Int(percent))%", percent: percent)
                            }
                        }
                    }
                    if needsVADModel {
                        DispatchQueue.main.async {
                            self?.statusBar.updateDownloadProgress("Downloading voice activity model...")
                        }
                        try ModelDownloader.downloadVAD { percent in
                            DispatchQueue.main.async {
                                self?.statusBar.updateDownloadProgress("Downloading voice activity model... \(Int(percent))%", percent: percent)
                            }
                        }
                    }
                    DispatchQueue.main.async {
                        self?.statusBar.state = .idle
                        self?.statusBar.updateDownloadProgress(nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        print("Error downloading model: \(error.localizedDescription)")
                        self?.statusBar.state = .error(error.localizedDescription)
                        self?.statusBar.buildMenu()
                    }
                }
            }
        }

        statusBar.buildMenu()

        let hotkeyDesc = config.hotkeySummary()
        print("Config updated: lang=\(config.language) model=\(config.modelSize) hotkey=\(hotkeyDesc)")
    }

    private func makeTranscriber(for config: Config) -> Transcriber {
        let transcriber = Transcriber(
            modelSize: config.modelSize,
            language: config.language,
            whisperPrompt: config.whisperPrompt,
            vadEnabled: config.isVADEnabled,
            vadThreshold: config.effectiveVADThreshold
        )
        transcriber.spokenPunctuation = config.spokenPunctuation?.value ?? false
        transcriber.customDictionary = config.customDictionary ?? []
        return transcriber
    }

    private func handleKeyDown() {
        guard isReady else { return }

        let isToggle = config.toggleMode?.value ?? false

        switch recordingLifecycle.keyDown(toggleMode: isToggle) {
        case .startRecording:
            handleRecordingStart()
        case .stopRecording:
            handleRecordingStop()
        case .none, .cancelRecording, .prepareRecorder:
            break
        }
    }

    private func handleKeyUp() {
        guard isReady else { return }

        let isToggle = config.toggleMode?.value ?? false

        if recordingLifecycle.keyUp(toggleMode: isToggle) == .stopRecording {
            handleRecordingStop()
        }
    }

    private func handleRecordingStart() {
        statusBar.state = .recording
        do {
            recorder.preferredDeviceID = AudioDeviceManager.resolveConfiguredDeviceID(
                uid: config.audioInputDeviceUID,
                legacyID: config.audioInputDeviceID
            )
            let outputURL: URL
            if Config.effectiveMaxRecordings(config.maxRecordings) == 0 {
                outputURL = RecordingStore.tempRecordingURL()
            } else {
                outputURL = RecordingStore.newRecordingURL()
            }
            try recorder.startRecording(to: outputURL)
            currentRecordingURL = outputURL
            if config.isSoundFeedbackEnabled {
                recordingSoundFeedback.playStarted()
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            recordingLifecycle.recordingStartFailed()
            currentRecordingURL = nil
            statusBar.state = .idle
        }
    }

    private func handleRecordingStop() {
        guard let audioURL = recorder.stopRecording() else {
            RecordingCancellation.discardTrackedPartialRecording(&currentRecordingURL)
            statusBar.state = .idle
            return
        }

        currentRecordingURL = nil
        statusBar.state = .transcribing
        if config.isSoundFeedbackEnabled {
            recordingSoundFeedback.playStopped()
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let maxRecordings = Config.effectiveMaxRecordings(self.config.maxRecordings)
            defer {
                if maxRecordings == 0 {
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
            do {
                let raw = try self.transcriber.transcribe(audioURL: audioURL)
                let text = self.postProcess(raw)
                if maxRecordings > 0 {
                    RecordingStore.prune(maxCount: maxRecordings)
                }
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        self.lastTranscription = text
                        if self.inserter.insert(text: text) == .copiedToClipboard {
                            self.statusBar.state = .copiedToClipboard
                            self.statusBar.buildMenu()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                if case .copiedToClipboard = self.statusBar.state {
                                    self.statusBar.state = .idle
                                    self.statusBar.buildMenu()
                                }
                            }
                            return
                        }
                    }
                    self.statusBar.state = .idle
                    self.statusBar.buildMenu()
                }
            } catch {
                if maxRecordings > 0 {
                    RecordingStore.prune(maxCount: maxRecordings)
                }
                DispatchQueue.main.async {
                    print("Error: \(error.localizedDescription)")
                    self.statusBar.state = .error(error.localizedDescription)
                    self.statusBar.buildMenu()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        if case .error = self.statusBar.state {
                            self.statusBar.state = .idle
                            self.statusBar.buildMenu()
                        }
                    }
                }
            }
        }
    }

    private func postProcess(_ raw: String) -> String {
        var text = (config.spokenPunctuation?.value ?? false) ? TextPostProcessor.process(raw) : raw
        text = DictionaryPostProcessor.process(text, dictionary: config.customDictionary ?? [])
        return text
    }

    func handleSystemWillSleep() {
        recorder.teardown()
        guard recordingLifecycle.systemWillSleep() == .cancelRecording else { return }

        RecordingCancellation.discardTrackedPartialRecording(&currentRecordingURL)
        resetRecordingStatusToIdleIfNeeded()
    }

    func handleSystemDidWake() {
        guard recordingLifecycle.systemDidWake(isReady: isReady) == .prepareRecorder else { return }

        recorder.preferredDeviceID = AudioDeviceManager.resolveConfiguredDeviceID(
            uid: config.audioInputDeviceUID,
            legacyID: config.audioInputDeviceID
        )
        recorder.prepare()
    }

    private func registerSleepWakeObservers() {
        guard sleepWakeObservers.isEmpty else { return }

        let center = NSWorkspace.shared.notificationCenter
        sleepWakeObservers = [
            center.addObserver(
                forName: NSWorkspace.willSleepNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleSystemWillSleep()
            },
            center.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.handleSystemDidWake()
            },
        ]
    }

    private func unregisterSleepWakeObservers() {
        let center = NSWorkspace.shared.notificationCenter
        for observer in sleepWakeObservers {
            center.removeObserver(observer)
        }
        sleepWakeObservers = []
    }

    private func resetRecordingStatusToIdleIfNeeded() {
        guard case .recording = statusBar.state else { return }
        statusBar.state = .idle
        statusBar.buildMenu()
    }

    public func reprocess(audioURL: URL) {
        guard case .idle = statusBar.state else { return }

        statusBar.state = .transcribing

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let raw = try self.transcriber.transcribe(audioURL: audioURL)
                let text = self.postProcess(raw)
                DispatchQueue.main.async {
                    if !text.isEmpty {
                        self.lastTranscription = text
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                        self.statusBar.state = .copiedToClipboard
                        self.statusBar.buildMenu()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            self.statusBar.state = .idle
                            self.statusBar.buildMenu()
                        }
                    } else {
                        self.statusBar.state = .idle
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    print("Reprocess error: \(error.localizedDescription)")
                    self.statusBar.state = .idle
                }
            }
        }
    }
}
