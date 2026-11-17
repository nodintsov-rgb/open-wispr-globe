import AppKit
import Foundation

final class Harness {
    var manager: HotkeyManager!
    var handler: ((NSEvent) -> Void)?
    var timer: (() -> Void)?
    var delay: TimeInterval = -1
    var cancelled = false
    var down = 0
    var up = 0

    init(delay: TimeInterval = 0.35) {
        manager = HotkeyManager(keyCode: 63, holdDelay: delay,
            scheduleHold: { [unowned self] delay, action in
                self.delay = delay; self.timer = action
                return { self.cancelled = true }
            },
            addGlobalMonitor: { [unowned self] _, action in self.handler = action; return NSObject() },
            addLocalMonitor: { _, _ in NSObject() }, removeMonitor: { _ in })
        manager.start(onKeyDown: { [unowned self] in self.down += 1 },
                      onKeyUp: { [unowned self] in self.up += 1 })
    }
    func send(_ pressed: Bool) {
        handler?(NSEvent.keyEvent(with: .flagsChanged, location: .zero,
            modifierFlags: pressed ? [.function] : [], timestamp: 0, windowNumber: 0,
            context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 63)!)
    }
}

@main struct Check {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
    static func main() {
        let tap = Harness()
        tap.send(true); tap.send(false); tap.timer?()
        require(tap.down == 0 && tap.up == 0 && tap.cancelled, "short tap started recording")
        require(tap.delay == 0.35, "wrong hold delay")
        print("PASS short tap and late cancelled timer")

        let hold = Harness()
        hold.send(true); hold.send(true); hold.timer?(); hold.send(true)
        require(hold.down == 1 && hold.up == 0, "duplicate flags interrupted hold")
        hold.send(false); hold.send(false)
        require(hold.up == 1, "release not delivered exactly once")
        print("PASS hold and duplicate press/release events")

        let stopped = Harness()
        stopped.send(true); stopped.manager.stop(); stopped.timer?()
        require(stopped.down == 0, "timer ran after stop")
        print("PASS stop cancels pending recording")

        let shortcut = Harness()
        shortcut.send(true)
        shortcut.handler?(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.function], timestamp: 0, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 51)!)
        shortcut.timer?(); shortcut.send(false)
        require(shortcut.down == 0 && shortcut.up == 0, "Fn+Delete started recording")
        print("PASS Fn shortcut cancels pending recording")

        let repressed = Harness()
        repressed.send(true); let oldTimer = repressed.timer
        repressed.send(false); repressed.send(true); oldTimer?()
        require(repressed.down == 0, "stale timer activated new press")
        repressed.timer?(); repressed.send(false)
        require(repressed.down == 1 && repressed.up == 1, "new hold failed")
        print("PASS stale timer isolation")

        let immediate = Harness(delay: 0)
        immediate.send(true); immediate.send(true); immediate.send(false)
        require(immediate.down == 1 && immediate.up == 1, "toggle mode regressed")
        print("PASS zero-delay toggle mode compatibility")
    }
}
