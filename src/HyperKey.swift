//
//  HyperKey.swift
//  LazyKeys
//
//  Purpose: Core key remapping engine that intercepts keyboard events and applies transformations.
//           Implements the Hyper key functionality by remapping Caps Lock to F18 and intercepting
//           F18 events to apply modifier key combinations or trigger custom key presses.
//

import Carbon
import Cocoa
import Foundation

// MARK: - KeyMappingMode Enum

/// Defines the available key mapping modes for quick press behavior.
///
/// The key mapping mode determines what happens when the user quickly taps
/// the Caps Lock key (as opposed to holding it down for Hyper key functionality).
enum KeyMappingMode {
    /// Default mode: Quick press toggles the Caps Lock state
    case capslock

    /// Custom mode: Quick press sends a specified virtual key code
    /// - Parameter keyCode: The virtual key code to send (e.g., Escape, Space)
    case custom(keyCode: UInt8)
}

// MARK: - Global Signal Handler Support

/// Global reference to the active HyperKey instance.
///
/// This is necessary for C signal handlers to access the HyperKey instance,
/// as C functions cannot capture Swift context or closures. This allows signal
/// handlers to call cleanup methods before the process terminates.
///
/// - Warning: This is a necessary evil due to C signal handler limitations.
///            In a perfect world, this wouldn't be global.
var hyperKeyInstance: HyperKey?

/// Signal handler function for graceful shutdown.
///
/// This C-compatible function is called when the application receives termination
/// signals (SIGINT, SIGTERM, SIGQUIT). It ensures that key mappings are properly
/// reset before the process exits.
///
/// - Parameter signal: The signal number that triggered the handler
func handleSignal(_: Int32) {
    // Reset key mappings to restore default behavior
    hyperKeyInstance?.resetKeyMapping()
    // Exit cleanly
    exit(0)
}

// MARK: - HyperKey Class

/// Core key remapping engine that transforms Caps Lock into a Hyper key.
///
/// This class is the heart of LazyKeys. It performs the following functions:
///
/// **System-Level Key Remapping:**
/// - Uses `hidutil` to remap Caps Lock (0x70000039) to F18 (0x7000006D) at the hardware level
/// - This remapping persists at the HID (Human Interface Device) layer
///
/// **Event Interception:**
/// - Creates a CGEvent tap to intercept all keyboard events system-wide
/// - Monitors for F18 key events (our remapped Caps Lock)
/// - Distinguishes between hold and quick press behaviors
///
/// **Hyper Key Functionality (Hold):**
/// - When F18 is held down, applies Hyper key modifiers (Cmd+Ctrl+Alt, optionally +Shift)
/// - Preserves any manually added modifiers (e.g., user can hold Shift separately)
///
/// **Quick Press Functionality:**
/// - When F18 is quickly tapped and released, triggers configured action:
///   - Default: Toggle Caps Lock state
///   - Custom: Send a specific key (e.g., Escape, Space)
/// - Only triggers if the key wasn't used as a modifier (smart detection)
///
/// **Cleanup and Signal Handling:**
/// - Registers signal handlers for graceful shutdown
/// - Resets key mappings on deinitialization to prevent system inconsistencies
class HyperKey {
    // MARK: - Properties

    /// The CGEvent tap port that intercepts keyboard events.
    private var eventTap: CFMachPort?

    /// The run loop source associated with the event tap.
    private var runLoopSource: CFRunLoopSource?

    /// Whether quick press functionality is enabled.
    private var normalQuickPress: Bool

    /// Whether to include Shift in the Hyper key combination.
    private var includeShift: Bool

    /// The current key mapping mode (Caps Lock toggle or custom key).
    private var keyMappingMode: KeyMappingMode

    /// Timestamp of the last F18 key down event (unused but kept for future timing features).
    private var lastKeyDown: Date?

    /// Tracks whether F18 is currently held down.
    private var f18Down = false

    /// Tracks whether the current F18 press has been used as a modifier.
    /// This prevents quick press actions from triggering when the key was used for Hyper key.
    private var quickPressHandled = false

    /// Manager for controlling the system Caps Lock state.
    private var capsLockManager = CapsLockManager()

    // MARK: - Initialization and Deinitialization

    /// Initializes the HyperKey remapping engine.
    ///
    /// This constructor performs the complete initialization sequence:
    /// 1. Stores configuration options
    /// 2. Creates the CGEvent tap for keyboard interception
    /// 3. Maps Caps Lock to F18 using hidutil
    /// 4. Registers signal handlers for clean shutdown
    ///
    /// - Parameters:
    ///   - normalQuickPress: Whether quick press functionality is enabled
    ///   - includeShift: Whether to include Shift in the Hyper key combination
    ///   - keyMappingMode: The mapping mode for quick press behavior (default: `.capslock`)
    init(normalQuickPress: Bool, includeShift: Bool, keyMappingMode: KeyMappingMode = .capslock) {
        self.normalQuickPress = normalQuickPress
        self.includeShift = includeShift
        self.keyMappingMode = keyMappingMode

        // Set up the event tap to intercept keyboard events
        setupEventTap()

        // Remap Caps Lock to F18 at the system level
        mapCapsLockToF18()

        // Register handlers for termination signals
        registerSignalHandlers()
    }

    /// Cleans up resources and resets key mappings when the instance is destroyed.
    ///
    /// This ensures that:
    /// - The event tap is properly invalidated
    /// - The run loop source is removed
    /// - Key mappings are reset to default state
    ///
    /// This prevents the system from being left in an inconsistent state if the
    /// application crashes or is forcefully terminated.
    deinit {
        // Invalidate the event tap
        if let tap = eventTap {
            CFMachPortInvalidate(tap)
        }

        // Remove the run loop source
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }

        // Reset key mappings to restore default behavior
        resetKeyMapping()
    }

    // MARK: - Key Mapping (hidutil)

    /// Maps Caps Lock to F18 at the system level using hidutil.
    ///
    /// This uses the `hidutil` command-line tool to remap Caps Lock (HID usage 0x70000039)
    /// to F18 (HID usage 0x7000006D). The remapping occurs at the HID driver level,
    /// before normal keyboard event processing, ensuring reliable interception.
    ///
    /// **Why F18?**
    /// - F18 is rarely used on modern keyboards
    /// - It's unlikely to conflict with existing shortcuts
    /// - It provides a "clean slate" for our custom behavior
    ///
    /// - Note: Based on the excellent article by Ryan Hanson:
    ///         https://medium.com/ryan-hanson/key-remapping-built-into-macos-c7953b1a62e4
    private func mapCapsLockToF18() {
        let mapping: [[String: Any]] = [
            [
                "HIDKeyboardModifierMappingSrc": 0x7_0000_0039, // Caps Lock HID usage
                "HIDKeyboardModifierMappingDst": 0x7_0000_006D, // F18 HID usage
            ],
        ]
        executeHidutil(payload: ["UserKeyMapping": mapping])
    }

    /// Resets the key mapping to restore default Caps Lock behavior.
    ///
    /// This clears the UserKeyMapping property, removing any custom key remappings
    /// and restoring the system to its default state. This is called during cleanup
    /// to ensure the user's keyboard returns to normal after the application exits.
    func resetKeyMapping() {
        executeHidutil(payload: ["UserKeyMapping": []])
    }

    /// Executes the hidutil command with the specified payload.
    ///
    /// This is a helper method that constructs and runs the hidutil command with
    /// a JSON payload. hidutil is Apple's built-in tool for modifying keyboard
    /// and pointing device properties at the driver level.
    ///
    /// - Parameter payload: A dictionary to be serialized as JSON and passed to hidutil
    ///
    /// - Note: Errors are logged but not thrown, as hidutil failures are typically
    ///         non-recoverable and indicate system-level issues.
    private func executeHidutil(payload: [String: Any]) {
        // Serialize the payload to JSON
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: []
            ),
            let json = String(data: data, encoding: .utf8)
        else {
            return
        }

        // Configure and run the hidutil process
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", json]

        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            NSLog("hidutil execution failed: \(error)")
        }
    }

    // MARK: - Event Tap Setup

    /// Sets up the CGEvent tap to intercept keyboard events.
    ///
    /// This method creates a system-wide event tap that monitors keyboard events:
    /// - `keyDown`: When a key is pressed
    /// - `keyUp`: When a key is released
    /// - `flagsChanged`: When modifier keys change state
    ///
    /// The event tap is inserted at the session level, meaning it intercepts events
    /// for the current login session. It's configured to:
    /// - Run at head insertion point (early in the event processing pipeline)
    /// - Use default tap behavior (can filter or modify events)
    /// - Pass events to our `handleEvent` callback
    ///
    /// - Note: This requires accessibility permissions, which are checked during app launch.
    private func setupEventTap() {
        // Create event mask for the types of events we want to monitor
        let mask =
            (1 << CGEventType.keyDown.rawValue)       // Key press events
                | (1 << CGEventType.keyUp.rawValue)   // Key release events
                | (1 << CGEventType.flagsChanged.rawValue) // Modifier key changes

        // Create the event tap
        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,           // Session-level tap
                place: .headInsertEventTap,        // Insert early in event pipeline
                options: .defaultTap,              // Can filter and modify events
                eventsOfInterest: CGEventMask(mask), // Events we want to intercept
                callback: { proxy, type, event, ref in
                    // Extract the HyperKey instance from the user info pointer
                    let obj = Unmanaged<HyperKey>.fromOpaque(ref!)
                        .takeUnretainedValue()
                    // Delegate to the instance's event handler
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
            NSLog("Failed to create event tap. Please enable Accessibility permissions in System Settings.")
            return
        }

        // Store the event tap and add it to the run loop
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            tap,
            0
        )
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    // MARK: - Event Handling

    /// Handles intercepted keyboard events from the CGEvent tap.
    ///
    /// This is the core event processing logic. It:
    /// 1. Detects F18 key events (our remapped Caps Lock)
    /// 2. Tracks whether F18 is held down or released
    /// 3. Applies Hyper key modifiers to other keys when F18 is held
    /// 4. Triggers quick press actions when F18 is quickly tapped
    ///
    /// - Parameters:
    ///   - proxy: The event tap proxy (unused)
    ///   - type: The type of event (keyDown, keyUp, flagsChanged)
    ///   - event: The keyboard event to process
    ///
    /// - Returns: The event to pass through (potentially modified), or `nil` to suppress it
    private func handleEvent(
        proxy _: CGEventTapProxy?,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Process key down and key up events
        if type == .keyDown || type == .keyUp {
            let code = UInt8(event.getIntegerValueField(.keyboardEventKeycode))

            // Check if this is our remapped F18 key (originally Caps Lock)
            if code == UInt8(kVK_F18) {
                if type == .keyDown {
                    // F18 pressed - start tracking for Hyper key functionality
                    f18Down = true
                    lastKeyDown = Date()
                    quickPressHandled = false
                } else {
                    // F18 released - stop tracking and check for quick press
                    f18Down = false
                    handleQuickPress()
                }
                // Suppress the F18 event itself (we don't want it to propagate)
                return nil
            }
        }

        // If F18 is currently held down, apply Hyper key modifiers to other keys
        if f18Down {
            return handleHyperKeyModifiers(type: type, event: event)
        }

        // Pass through all other events unmodified
        return Unmanaged.passUnretained(event)
    }

    /// Applies Hyper key modifiers to keyboard events when F18 is held down.
    ///
    /// This method modifies the event's flags to include the Hyper key modifiers:
    /// - Command (⌘)
    /// - Control (⌃)
    /// - Option/Alt (⌥)
    /// - Shift (⇧) - optional, based on configuration
    ///
    /// **Smart Modifier Preservation:**
    /// - Preserves any modifiers manually added by the user (e.g., holding Shift separately)
    /// - Preserves the Fn (Function) key state
    /// - Only applies modifiers to non-F18 keys
    ///
    /// - Parameters:
    ///   - type: The type of event (unused)
    ///   - event: The keyboard event to modify
    ///
    /// - Returns: The modified event with Hyper key modifiers applied
    private func handleHyperKeyModifiers(type _: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let code = UInt8(event.getIntegerValueField(.keyboardEventKeycode))

        // Only modify non-F18 key events
        if code != UInt8(kVK_F18) {
            // Get the current modifier flags from the event
            let currentFlags = event.flags

            // Create base Hyper key modifiers: Command + Control + Option
            var hyperFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate]

            // Add Shift if configured to do so
            if includeShift {
                hyperFlags.insert(.maskShift)
            }

            // Preserve manually added Shift if not already included
            if !includeShift && currentFlags.contains(.maskShift) {
                hyperFlags.insert(.maskShift)
            }

            // Preserve the Fn (Function) key state
            if currentFlags.contains(.maskSecondaryFn) {
                hyperFlags.insert(.maskSecondaryFn)
            }

            // Apply the combined modifier flags to the event
            event.flags = hyperFlags

            // Mark that this F18 press was used as a modifier
            // This prevents quick press actions from triggering
            quickPressHandled = true
        }

        return Unmanaged.passUnretained(event)
    }

    // MARK: - Quick Press Handling

    /// Handles the quick press action when F18 is quickly tapped and released.
    ///
    /// This method is called when F18 is released. It checks whether the key press
    /// was used as a modifier (for Hyper key functionality) or was a standalone tap.
    ///
    /// **Quick Press Behavior:**
    /// - **Caps Lock Mode**: Toggles the system Caps Lock state
    /// - **Custom Key Mode**: Sends the configured custom key press
    ///
    /// **Smart Detection:**
    /// - Only triggers if `normalQuickPress` is enabled
    /// - Only triggers if the key wasn't used as a modifier (`!quickPressHandled`)
    /// - This prevents accidental triggers when using Hyper key combinations
    private func handleQuickPress() {
        // Check if quick press functionality is enabled
        guard normalQuickPress else { return }

        // Only trigger if the key wasn't used as a modifier
        if !quickPressHandled {
            switch keyMappingMode {
            case .capslock:
                // Default behavior: Toggle Caps Lock state
                capsLockManager.toggleState()

            case let .custom(keyCode):
                // Custom behavior: Send the configured key press
                sendKeyPress(keyCode: keyCode)
            }
        }
    }

    /// Sends a synthetic key press event for the specified virtual key code.
    ///
    /// This method creates and posts both key down and key up events for the
    /// specified key, simulating a complete key press and release cycle.
    ///
    /// - Parameter keyCode: The virtual key code to send (e.g., kVK_Escape, kVK_Space)
    ///
    /// - Note: Events are posted to `.cghidEventTap`, which injects them at the
    ///         HID level, making them indistinguishable from real key presses.
    private func sendKeyPress(keyCode: UInt8) {
        // Create and post key down event
        if let keyDownEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: true
        ) {
            keyDownEvent.post(tap: .cghidEventTap)
        }

        // Create and post key up event
        if let keyUpEvent = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(keyCode),
            keyDown: false
        ) {
            keyUpEvent.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Signal Handling

    /// Registers signal handlers for graceful shutdown.
    ///
    /// This method sets up handlers for common termination signals:
    /// - **SIGINT**: Interrupt signal (Ctrl+C)
    /// - **SIGTERM**: Termination signal (kill command)
    /// - **SIGQUIT**: Quit signal (Ctrl+\)
    ///
    /// When any of these signals are received, the `handleSignal` function is called,
    /// which resets key mappings before exiting. This ensures the system is left in
    /// a clean state even if the application is terminated unexpectedly.
    private func registerSignalHandlers() {
        signal(SIGINT, handleSignal)   // Ctrl+C
        signal(SIGTERM, handleSignal)  // Termination
        signal(SIGQUIT, handleSignal)  // Quit
    }
}
