//
//  CapsLockManager.swift
//  CapsLockNoDelay
//
//  Created by Guy Kaplan on 31/10/2020.
//
// Source: https://github.com/gkpln3/CapsLockNoDelay/blob/main/CapsLockNoDelay/CapsLockManager.swift

import Foundation
import os.log

class CapsLockManager: Toggleable {
    var currentState = false
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "Startup")

    init() {
        currentState = Self.getCapsLockState()
    }

    public func toggleState() {
        logger.info("setting state \(!self.currentState)")
        setCapsLockState(!currentState)
    }

    public func setCapsLockState(_ state: Bool) {
        currentState = state
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kIOHIDSystemClass))
        IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)
        IOHIDSetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), state)
        IOServiceClose(ioConnect)
    }

    public static func getCapsLockState() -> Bool {
        var ioConnect: io_connect_t = .init(0)
        let ioService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(kIOHIDSystemClass))
        IOServiceOpen(ioService, mach_task_self_, UInt32(kIOHIDParamConnectType), &ioConnect)

        var modifierLockState = false
        IOHIDGetModifierLockState(ioConnect, Int32(kIOHIDCapsLockState), &modifierLockState)

        IOServiceClose(ioConnect)
        return modifierLockState
    }
}
