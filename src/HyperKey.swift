import Carbon
import Cocoa
import Foundation

// Enum for different key mapping modes
enum KeyMappingMode {
    case capslock
    case custom(keyCode: UInt8)
}

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
    private var keyMappingMode: KeyMappingMode
    private var lastKeyDown: Date?
    private var f18Down = false
    private var quickPressHandled = false
    private var capsLockManager = CapsLockManager()

    init(normalQuickPress: Bool, includeShift: Bool, keyMappingMode: KeyMappingMode = .capslock) {
        self.normalQuickPress = normalQuickPress
        self.includeShift = includeShift
        self.keyMappingMode = keyMappingMode
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

        // Long press is ALWAYS hyperkey - apply hyperkey modifiers when F18 is held
        if f18Down {
            return handleHyperKeyModifiers(type: type, event: event)
        }

        return Unmanaged.passUnretained(event)
    }

    private func handleHyperKeyModifiers(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Only modify non-F18 key events
        let code = UInt8(event.getIntegerValueField(.keyboardEventKeycode))
        if code != UInt8(kVK_F18) {
            // Get the current flags from the event
            let currentFlags = event.flags

            // Create base hyper key modifiers (Command + Control + Option)
            var hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]

            // Add shift by default if includeShift flag is set
            if includeShift {
                hyperFlags.insert(.maskShift)
            }

            // Preserve any manually added modifiers that are already present in the event
            if !includeShift && currentFlags.contains(.maskShift) {
                hyperFlags.insert(.maskShift)
            }

            // Preserve any other potential modifiers
            if currentFlags.contains(.maskSecondaryFn) {
                hyperFlags.insert(.maskSecondaryFn)
            }

            // Apply the combined flags to the event
            event.flags = hyperFlags

            // Mark as handled since we used it as a modifier
            quickPressHandled = true
        }

        return Unmanaged.passUnretained(event)
    }


    private func handleQuickPress() {
        guard normalQuickPress else { return }

        // Only trigger quick press action if the key wasn't used as a modifier
        if !quickPressHandled {
            switch keyMappingMode {
            case .capslock:
                // Original behavior - toggle caps lock
                capsLockManager.toggleState()
            case .custom(let keyCode):
                // Send custom key
                sendKeyPress(keyCode: keyCode)
            }
        }
    }

    private func sendKeyPress(keyCode: UInt8) {
        // Create and post key down event
        if let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: true) {
            keyDownEvent.post(tap: .cghidEventTap)
        }

        // Create and post key up event
        if let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCode), keyDown: false) {
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }

    // Register signal handlers for SIGINT, SIGTERM, and SIGQUIT
    private func registerSignalHandlers() {
        signal(SIGINT, handleSignal)
        signal(SIGTERM, handleSignal)
        signal(SIGQUIT, handleSignal)
    }
}
