//
//  CapsLockManager.swift
//  LazyKeys
//
//  Created by Guy Kaplan on 31/10/2020.
//  Source: https://github.com/gkpln3/CapsLockNoDelay/blob/main/CapsLockNoDelay/CapsLockManager.swift
//
//  Purpose: Manages the Caps Lock state via IOKit system-level APIs.
//           Provides functionality to read and modify the Caps Lock state
//           at the hardware level, bypassing standard keyboard input mechanisms.
//

import Foundation
import os.log

// MARK: - CapsLockManager Class

/// Manages the system-level Caps Lock state using IOKit APIs.
///
/// This class provides direct access to the hardware Caps Lock state through
/// the IOHIDSystem service. It can query and modify the Caps Lock state at
/// a level below normal keyboard input processing, ensuring reliable control
/// even when keyboard events are being intercepted by event taps.
///
/// The class conforms to `Toggleable` to provide a consistent interface for
/// state toggling operations used throughout the application.
class CapsLockManager: Toggleable {
    // MARK: - Properties

    /// The current known state of the Caps Lock key.
    /// - Note: This is synchronized with the actual hardware state via IOKit.
    var currentState = false

    /// Logger for tracking Caps Lock state changes and debugging.
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "CapsLock")

    // MARK: - Initialization

    /// Initializes the Caps Lock manager and synchronizes with the current hardware state.
    ///
    /// Queries the system to get the actual Caps Lock state at initialization time,
    /// ensuring the manager's internal state matches reality.
    init() {
        currentState = Self.getCapsLockState()
    }

    // MARK: - Public Methods

    /// Toggles the Caps Lock state between on and off.
    ///
    /// This method implements the `Toggleable` protocol requirement and provides
    /// a convenient way to flip the Caps Lock state without needing to know its
    /// current value.
    public func toggleState() {
        logger.info("Toggling Caps Lock state: \(self.currentState) -> \(!self.currentState)")
        setCapsLockState(!currentState)
    }

    /// Sets the Caps Lock state to the specified value.
    ///
    /// This method directly communicates with the IOHIDSystem to set the hardware
    /// Caps Lock state. It performs the following steps:
    /// 1. Opens a connection to the IOHIDSystem service
    /// 2. Sets the modifier lock state for Caps Lock
    /// 3. Closes the connection
    ///
    /// - Parameter state: The desired Caps Lock state (`true` for on, `false` for off)
    ///
    /// - Note: This operation requires the application to have proper accessibility permissions.
    public func setCapsLockState(_ state: Bool) {
        // Update internal state tracking
        currentState = state

        // Open connection to IOHIDSystem service
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kIOHIDSystemClass))
        IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)

        // Set the Caps Lock modifier state at the hardware level
        IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), state)

        // Clean up: close the IOKit connection
        IOServiceClose(ioConnect)
    }

    // MARK: - Static Methods

    /// Retrieves the current hardware Caps Lock state from the system.
    ///
    /// This static method queries the IOHIDSystem service to determine whether
    /// Caps Lock is currently enabled or disabled at the hardware level.
    ///
    /// The method performs the following steps:
    /// 1. Opens a connection to the IOHIDSystem service
    /// 2. Queries the modifier lock state for Caps Lock
    /// 3. Closes the connection
    /// 4. Returns the current state
    ///
    /// - Returns: `true` if Caps Lock is currently on, `false` if it's off
    ///
    /// - Note: This is a static method because it's useful to query the Caps Lock
    ///         state without needing to instantiate a CapsLockManager object.
    public static func getCapsLockState() -> Bool {
        // Open connection to IOHIDSystem service
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kIOHIDSystemClass))
        IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)

        // Query the current Caps Lock state
        var modifierLockState = false
        IOHIDGetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), &modifierLockState)

        // Clean up: close the IOKit connection
        IOServiceClose(ioConnect)

        return modifierLockState
    }
}
