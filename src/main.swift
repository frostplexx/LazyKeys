import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var hyperKey: HyperKey?
    private var statusItem: NSStatusItem?
// Use VERSION_STRING from version.h
let version = String(cString: VERSION_STRING)

    func applicationDidFinishLaunching(_ notification: Notification) {
        var normalQuickPress = true
        var includeShift = false

        if CommandLine.arguments.contains("--version") {
            print("LazyKeys version \(version)")
            exit(0)
        }

        for arg in CommandLine.arguments.dropFirst() {
            if arg == "--no-quick-press" {
                normalQuickPress = false
            } else if arg == "--include-shift" {
                includeShift = true
            }
        }

        let options =
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            as CFDictionary
        if !AXIsProcessTrustedWithOptions(options) {
            NSLog("Enable Accessibility in System Settings → Privacy → Accessibility")
        }

        hyperKey = HyperKey(normalQuickPress: normalQuickPress, includeShift: includeShift)
        hyperKeyInstance = hyperKey  // Set global reference to the instance

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(applicationWillTerminate(_:)),
                                               name: NSApplication.willTerminateNotification,
                                               object: nil)
    }

    @objc func applicationWillTerminate(_ notification: Notification) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        proc.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        try? proc.run()
    }
}

// Main function that starts the application
func main() {
    let delegate = AppDelegate()
    NSApplication.shared.delegate = delegate
    NSApplication.shared.run()
}

// Call main to start the app
main()
