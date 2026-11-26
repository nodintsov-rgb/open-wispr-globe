import AppKit
import AVFoundation
import ApplicationServices
import Foundation

struct Permissions {
    static var microphoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static func requestMicrophone(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        default:
            completion(false)
        }
    }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func shouldResetAccessibility(afterUpgrade: Bool, isTrusted: Bool) -> Bool {
        afterUpgrade && !isTrusted
    }

    static func resetAccessibility() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", "com.human37.open-wispr"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func didUpgrade() -> Bool {
        didUpgrade(versionFile: versionFile, currentVersion: OpenWispr.version)
    }

    static func didUpgrade(versionFile: URL, currentVersion: String) -> Bool {
        let raw = (try? String(contentsOf: versionFile, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let previous = raw.isEmpty ? nil : raw
        return previous != nil && previous != currentVersion
    }

    static func recordCurrentVersion() {
        do {
            try recordCurrentVersion(to: versionFile, version: OpenWispr.version)
        } catch {
            print("Accessibility: could not record current version: \(error.localizedDescription)")
        }
    }

    static func recordCurrentVersion(to versionFile: URL, version: String) throws {
        try FileManager.default.createDirectory(
            at: versionFile.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try version.write(to: versionFile, atomically: true, encoding: .utf8)
    }

    private static var versionFile: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/open-wispr/.last-version")
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
