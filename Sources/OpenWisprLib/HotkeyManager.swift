import AppKit
import Foundation

class HotkeyManager {
    typealias GlobalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> Void) -> Any?
    typealias LocalMonitorInstaller = (NSEvent.EventTypeMask, @escaping (NSEvent) -> NSEvent?) -> Any?
    typealias HoldScheduler = (TimeInterval, @escaping () -> Void) -> (() -> Void)

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let keyCode: UInt16
    private let requiredModifiers: UInt64
    private let addGlobalMonitor: GlobalMonitorInstaller
    private let addLocalMonitor: LocalMonitorInstaller
    private let removeMonitor: (Any) -> Void
    private var onKeyDown: (() -> Void)?
    private var onKeyUp: (() -> Void)?
    private var modifierPressed = false
    private let holdDelay: TimeInterval
    private let scheduleHold: HoldScheduler
    private var cancelPendingHold: (() -> Void)?
    private var holdID: UUID?
    private var activated = false

    init(
        keyCode: UInt16,
        modifiers: UInt64 = 0,
        holdDelay: TimeInterval = 0,
        scheduleHold: @escaping HoldScheduler = { delay, action in
            let item = DispatchWorkItem(block: action)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
            return { item.cancel() }
        },
        addGlobalMonitor: @escaping GlobalMonitorInstaller = { mask, handler in
            NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler)
        },
        addLocalMonitor: @escaping LocalMonitorInstaller = { mask, handler in
            NSEvent.addLocalMonitorForEvents(matching: mask, handler: handler)
        },
        removeMonitor: @escaping (Any) -> Void = { NSEvent.removeMonitor($0) }
    ) {
        self.keyCode = keyCode
        self.requiredModifiers = modifiers
        self.holdDelay = holdDelay
        self.scheduleHold = scheduleHold
        self.addGlobalMonitor = addGlobalMonitor
        self.addLocalMonitor = addLocalMonitor
        self.removeMonitor = removeMonitor
    }

    func start(onKeyDown: @escaping () -> Void, onKeyUp: @escaping () -> Void) {
        self.onKeyDown = onKeyDown
        self.onKeyUp = onKeyUp

        let mask: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged]

        globalMonitor = addGlobalMonitor(mask) { [weak self] event in
            self?.handleEvent(event)
        }
        localMonitor = addLocalMonitor(mask) { [weak self] event in
            self?.handleEvent(event)
            return event
        }
    }

    func stop() {
        cancelHold()
        modifierPressed = false
        activated = false
        if let monitor = globalMonitor {
            removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            removeMonitor(monitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handleEvent(_ event: NSEvent) {
        // Fn is a flag, not an alternating toggle. Repeated flag notifications
        // must not turn a held key into several very short recordings.
        if keyCode == 63 {
            if event.type == .keyDown, event.keyCode != keyCode {
                // A short Fn shortcut (e.g. Fn+Delete) is not dictation.
                if !activated { cancelHold() }
                return
            }
            guard event.type == .flagsChanged, event.keyCode == keyCode else { return }
            let pressed = event.modifierFlags.contains(.function)
            guard pressed != modifierPressed else { return }
            modifierPressed = pressed
            if pressed {
                let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                guard currentMods & requiredModifiers == requiredModifiers else { return }
                if holdDelay > 0 {
                    let id = UUID()
                    holdID = id
                    cancelPendingHold = scheduleHold(holdDelay) { [weak self] in
                        guard let self, self.modifierPressed, self.holdID == id else { return }
                        self.holdID = nil
                        self.cancelPendingHold = nil
                        self.activated = true
                        self.onKeyDown?()
                    }
                } else {
                    activated = true
                    onKeyDown?()
                }
            } else {
                cancelHold()
                if activated {
                    activated = false
                    onKeyUp?()
                }
            }
            return
        }
        if isModifierOnlyKey(keyCode) {
            guard event.type == .flagsChanged else { return }
            guard event.keyCode == keyCode else { return }

            if modifierPressed {
                modifierPressed = false
                onKeyUp?()
            } else {
                if requiredModifiers != 0 {
                    let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                    guard currentMods & requiredModifiers == requiredModifiers else { return }
                }
                modifierPressed = true
                onKeyDown?()
            }
        } else {
            guard event.keyCode == keyCode else { return }
            if requiredModifiers != 0 {
                let currentMods = UInt64(event.modifierFlags.rawValue) & 0x00FF0000
                guard currentMods & requiredModifiers == requiredModifiers else { return }
            }
            if event.type == .keyDown {
                onKeyDown?()
            } else if event.type == .keyUp {
                onKeyUp?()
            }
        }
    }

    private func cancelHold() {
        holdID = nil
        cancelPendingHold?()
        cancelPendingHold = nil
    }

    private func isModifierOnlyKey(_ code: UInt16) -> Bool {
        return [54, 55, 56, 58, 59, 60, 61, 62, 63].contains(code)
    }
}
