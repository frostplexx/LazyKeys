//
//  Toggleable.swift
//  LazyKeys
//
//  Created by Guy Kaplan on 22/11/2022.
//  Source: https://github.com/gkpln3/CapsLockNoDelay/blob/main/CapsLockNoDelay/Toggleable.swift
//
//  Purpose: Provides a protocol for objects that can toggle their state.
//

import Foundation

// MARK: - Toggleable Protocol

/// Protocol for objects that support state toggling operations.
///
/// Conforming types should implement `toggleState()` to switch between
/// their primary binary states (e.g., on/off, enabled/disabled, locked/unlocked).
///
/// This protocol is primarily used by `CapsLockManager` to provide a consistent
/// interface for toggling the Caps Lock state.
protocol Toggleable {
    /// Toggles the current state of the conforming object.
    ///
    /// Implementations should switch from the current state to its opposite state.
    /// For example:
    /// - If currently on, switch to off
    /// - If currently enabled, switch to disabled
    func toggleState()
}
