import Carbon
import Cocoa
import os.log

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hyperKey: HyperKey?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private let cliParser = CLIParser()
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "Startup")


    func applicationDidFinishLaunching(_: Notification) {

        // Parse CLI arguments
        guard let options = cliParser.parseArguments() else {
            return // parseArguments() handles help/version and exits if needed
        }

        // Check accessibility permissions and wait if needed
        checkAndWaitForAccessibilityPermissions { [weak self] in
            guard let self = self else { return }

            // Permissions granted, initialize the app
            self.hyperKey = HyperKey(
                normalQuickPress: options.normalQuickPress,
                includeShift: options.includeShift,
                keyMappingMode: options.keyMappingMode
            )
            hyperKeyInstance = self.hyperKey

            self.logger.info("🚀 LazyKeys initialized successfully!")

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillTerminate(_:)),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        }
    }

    @objc func applicationWillTerminate(_: Notification) {
        self.logger.info("🛑 LazyKeys terminating...")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? proc.run()
    }

    private func checkAndWaitForAccessibilityPermissions(completion: @escaping () -> Void) {
        if AXIsProcessTrusted() {
            // Already have permissions, proceed immediately
            self.logger.info("✅ Accessibility permissions already granted")
            completion()
            return
        }

        // Don't have permissions, request them and start monitoring
        self.logger.info("⚠️  LazyKeys requires Accessibility permissions to function.")
        self.logger.info("📍 Please grant permission in System Settings → Privacy & Security → Accessibility")

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Flag to ensure completion is only called once
        var completionCalled = false

        let callCompletionOnce = {
            guard !completionCalled else { return }
            completionCalled = true

            self.permissionTimer?.invalidate()
            self.permissionTimer = nil
            self.logger.info("✅ Accessibility permissions granted! Initializing LazyKeys...")

            // Small delay to ensure system is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        }

        // Start timer to check for permissions every 2 seconds
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            if AXIsProcessTrusted() {
                callCompletionOnce()
            } else {
                self.logger.info("⏳ Still waiting for accessibility permissions...")
            }
        }
    }
}

func main() {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}


main()
