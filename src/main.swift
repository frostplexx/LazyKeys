//
//  main.swift
//  LazyKeys
//
//  Purpose: Application entry point and lifecycle management.
//           Handles initialization, accessibility permissions, and graceful shutdown.
//

import Carbon
import Cocoa
import os.log

// MARK: - AppDelegate Class

/// Main application delegate responsible for lifecycle management and initialization.
///
/// This class handles:
/// - Parsing command-line arguments
/// - Requesting and monitoring accessibility permissions
/// - Initializing the HyperKey remapping engine
/// - Cleaning up key mappings on termination
///
/// The application runs as a headless background process without a dock icon or menu bar,
/// continuously intercepting and transforming keyboard events according to user configuration.
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties

    /// The core HyperKey instance that handles all key remapping logic.
    private var hyperKey: HyperKey?

    /// Status bar item (currently unused, reserved for future UI features).
    private var statusItem: NSStatusItem?

    /// Timer used to periodically check if accessibility permissions have been granted.
    private var permissionTimer: Timer?

    /// Parser for handling command-line arguments and configuration.
    private let cliParser = CLIParser()

    /// Logger for tracking application lifecycle events.
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "Startup")

    // MARK: - Application Lifecycle

    /// Called when the application has finished launching.
    ///
    /// This method orchestrates the initialization sequence:
    /// 1. Parses command-line arguments
    /// 2. Checks for accessibility permissions
    /// 3. Waits for permissions if not already granted
    /// 4. Initializes the HyperKey remapping engine
    ///
    /// - Parameter notification: The application did finish launching notification
    func applicationDidFinishLaunching(_: Notification) {
        // Parse CLI arguments to determine operating mode and configuration
        guard let options = cliParser.parseArguments() else {
            // parseArguments() handles help/version display and exits if needed
            return
        }

        // Check accessibility permissions and wait if needed
        checkAndWaitForAccessibilityPermissions { [weak self] in
            guard let self = self else { return }

            // Permissions granted, initialize the HyperKey remapping engine
            self.hyperKey = HyperKey(
                normalQuickPress: options.normalQuickPress,
                includeShift: options.includeShift,
                keyMappingMode: options.keyMappingMode
            )

            // Store global reference for signal handlers
            // Note: This is necessary because C signal handlers can't capture Swift context
            hyperKeyInstance = self.hyperKey

            self.logger.info("🚀 LazyKeys initialized successfully!")

            // Register for termination notifications to clean up properly
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillTerminate(_:)),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        }
    }

    /// Called when the application is about to terminate.
    ///
    /// This method ensures that all key mappings are properly reset before the
    /// application exits, preventing the system from being left in an inconsistent
    /// state where Caps Lock might still be remapped to F18.
    ///
    /// - Parameter notification: The application will terminate notification
    @objc func applicationWillTerminate(_: Notification) {
        self.logger.info("🛑 LazyKeys terminating...")

        // Reset key mappings to restore default Caps Lock behavior
        // This uses hidutil to clear the UserKeyMapping property
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? proc.run()
    }

    // MARK: - Accessibility Permissions

    /// Checks for accessibility permissions and waits for them to be granted if necessary.
    ///
    /// macOS requires explicit user authorization for applications to monitor and intercept
    /// keyboard events. This method handles the entire permission flow:
    ///
    /// 1. If permissions are already granted, proceeds immediately
    /// 2. If not granted, displays a system permission dialog
    /// 3. Polls every 2 seconds until permissions are granted
    /// 4. Calls the completion handler once permissions are available
    ///
    /// - Parameter completion: Closure to be called once permissions are confirmed
    ///
    /// - Note: The application cannot function without accessibility permissions,
    ///         as they are required for CGEvent tap creation and keyboard event interception.
    private func checkAndWaitForAccessibilityPermissions(completion: @escaping () -> Void) {
        // Check if we already have the necessary accessibility permissions
        if AXIsProcessTrusted() {
            self.logger.info("✅ Accessibility permissions already granted")
            completion()
            return
        }

        // Don't have permissions yet - inform the user and request them
        self.logger.info("⚠️  LazyKeys requires Accessibility permissions to function.")
        self.logger.info("📍 Please grant permission in System Settings → Privacy & Security → Accessibility")

        // Display system permission dialog to the user
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Flag to ensure completion is only called once
        var completionCalled = false

        /// Helper closure to call completion exactly once, with proper cleanup
        let callCompletionOnce = {
            guard !completionCalled else { return }
            completionCalled = true

            // Stop the permission polling timer
            self.permissionTimer?.invalidate()
            self.permissionTimer = nil
            self.logger.info("✅ Accessibility permissions granted! Initializing LazyKeys...")

            // Small delay to ensure system is fully ready after permission grant
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }

        // Start periodic timer to poll for permission grants
        // This is necessary because there's no callback-based API for permission changes
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if AXIsProcessTrusted() {
                // Permissions have been granted!
                callCompletionOnce()
            } else {
                // Still waiting for user to grant permissions
                self.logger.info("⏳ Still waiting for accessibility permissions...")
            }
        }
    }
}

// MARK: - Application Entry Point

/// Application entry point.
///
/// Creates the AppDelegate and starts the Cocoa application run loop.
/// This function never returns under normal circumstances; the app runs
/// until it receives a termination signal or the user quits it.
func main() {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}

// Start the application
main()
