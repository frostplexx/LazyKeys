import Carbon
import Cocoa
import Foundation

// Global reference to HyperKey instance (to call methods from signal handlers)
var hyperKeyInstance: HyperKey? = nil

// C function to handle signals
func handleSignal(_ signal: Int32) {
    // Call the reset function on the HyperKey instance
    hyperKeyInstance?.resetKeyMapping()
    exit(0)  // Exit after resetting key mappings
}

// MARK: - HyperKey Class
class HyperKey {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var normalQuickPress: Bool
    private var includeShift: Bool
    private var lastKeyDown: Date?
    private var f18Down = false
    private var quickPressHandled = false
    private var capsLockManager = CapsLockManager()

    init(normalQuickPress: Bool, includeShift: Bool) {
        self.normalQuickPress = normalQuickPress
        self.includeShift = includeShift
        setupEventTap()
        mapCapsLockToF18()
        registerSignalHandlers()  // Register signal handlers
    }

    deinit {
        if let tap = eventTap { CFMachPortInvalidate(tap) }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
        resetKeyMapping()
    }

    // Source: https://medium.com/ryan-hanson/key-remapping-built-into-macos-c7953b1a62e4
    private func mapCapsLockToF18() {
        let mapping: [[String: Any]] = [
            [
                "HIDKeyboardModifierMappingSrc": 0x7_0000_0039,
                "HIDKeyboardModifierMappingDst": 0x7_0000_006D,
            ]
        ]
        executeHidutil(payload: ["UserKeyMapping": mapping])
    }

    func resetKeyMapping() {
        executeHidutil(payload: ["UserKeyMapping": []])
    }

    private func executeHidutil(payload: [String: Any]) {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: []
            ),
            let json = String(data: data, encoding: .utf8)
        else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", json]
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch { NSLog("hidutil failed: \(error)") }
    }

    private func setupEventTap() {
        let mask =
            (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: CGEventMask(mask),
                callback: { (proxy, type, event, ref) in
                    let obj = Unmanaged<HyperKey>.fromOpaque(ref!)
                        .takeUnretainedValue()
                    return obj.handleEvent(
                        proxy: proxy,
                        type: type,
                        event: event
                    )
                },
                userInfo: UnsafeMutableRawPointer(
                    Unmanaged.passUnretained(self).toOpaque()
                )
            )
        else {
            NSLog(
                "Failed to create event tap; enable Accessibility permissions."
            )
            return
        }
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        )
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func handleEvent(
        proxy: CGEventTapProxy?,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        if type == .keyDown || type == .keyUp {
            let code = UInt8(event.getIntegerValueField(.keyboardEventKeycode))
            if code == UInt8(kVK_F18) {
                if type == .keyDown {
                    f18Down = true
                    lastKeyDown = Date()
                    quickPressHandled = false
                } else {
                    f18Down = false
                    handleQuickPress()
                }
                return nil
            }
        }

        if f18Down {
            // Get the current flags from the event
            let currentFlags = event.flags
            
            // Create base hyper key modifiers (Command + Control + Option)
            var hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]
            
            // Add shift by default if includeShift flag is set
            if includeShift {
                hyperFlags.insert(.maskShift)
            }
            
            // Preserve any manually added modifiers that are already present in the event
            // This allows additional Shift and other modifiers to be added manually
            // even if includeShift is false
            if !includeShift && currentFlags.contains(.maskShift) {
                hyperFlags.insert(.maskShift)
            }
            
            // Preserve any other potential modifiers
            if currentFlags.contains(.maskSecondaryFn) {
                hyperFlags.insert(.maskSecondaryFn)
            }
            
            // Apply the combined flags to the event
            event.flags = hyperFlags
            quickPressHandled = true
        }
        return Unmanaged.passUnretained(event)
    }

    private func handleQuickPress() {
        guard normalQuickPress, let down = lastKeyDown else { return }
        if Date().timeIntervalSince(down) > 0.02 && !quickPressHandled {
            capsLockManager.toggleState()
            quickPressHandled = true
        }
    }

    // Register signal handlers for SIGINT, SIGTERM, and SIGQUIT
    private func registerSignalHandlers() {
        signal(SIGINT, handleSignal)
        signal(SIGTERM, handleSignal)
        signal(SIGQUIT, handleSignal)
    }
}
