import Carbon
import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hyperKey: HyperKey?
    private var statusItem: NSStatusItem?
    private var permissionTimer: Timer?
    private let cliParser = CLIParser()

    func applicationDidFinishLaunching(_: Notification) {
        print("📝 LazyKeys started at \(Date())")

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

            print("🚀 LazyKeys initialized successfully!")

            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.applicationWillTerminate(_:)),
                name: NSApplication.willTerminateNotification,
                object: nil
            )
        }
    }

    @objc func applicationWillTerminate(_: Notification) {
        print("🛑 LazyKeys terminating...")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? proc.run()
    }

    private func checkAndWaitForAccessibilityPermissions(completion: @escaping () -> Void) {
        if AXIsProcessTrusted() {
            // Already have permissions, proceed immediately
            print("✅ Accessibility permissions already granted")
            completion()
            return
        }

        // Don't have permissions, request them and start monitoring
        print("⚠️  LazyKeys requires Accessibility permissions to function.")
        print("📍 Please grant permission in System Settings → Privacy & Security → Accessibility")

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)

        // Flag to ensure completion is only called once
        var completionCalled = false

        let callCompletionOnce = {
            guard !completionCalled else { return }
            completionCalled = true

            self.permissionTimer?.invalidate()
            self.permissionTimer = nil
            print("✅ Accessibility permissions granted! Initializing LazyKeys...")

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
                print("⏳ Still waiting for accessibility permissions...")
            }
        }
    }
}

func main() {
    #if DEBUG
        setupDebugLogging()
    #endif

    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}

#if DEBUG
    func setupDebugLogging() {
        let logPath = "/tmp/lazykeys.log"

        // Ensure the log file exists
        if !FileManager.default.fileExists(atPath: logPath) {
            FileManager.default.createFile(atPath: logPath, contents: nil, attributes: nil)
        }

        // Redirect stdout
        if freopen(logPath, "a", stdout) == nil {
            NSLog("❌ Failed to redirect stdout to \(logPath)")
        }

        // Redirect stderr
        if freopen(logPath, "a", stderr) == nil {
            NSLog("❌ Failed to redirect stderr to \(logPath)")
        }

        // Disable buffering for immediate output
        setbuf(stdout, nil)
        setbuf(stderr, nil)

        // Log successful setup
        print("✅ LazyKeys (DEBUG) logging to \(logPath)")
        print(String(repeating: "=", count: 50))
        fflush(stdout)
    }
#endif

main()
