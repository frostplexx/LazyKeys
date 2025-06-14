import Carbon
import Foundation
import os.log

struct CLIOptions {
    let normalQuickPress: Bool
    let includeShift: Bool
    let keyMappingMode: KeyMappingMode
}

class CLIParser {
    private let version = String(cString: VERSION_STRING)
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "Startup")

    func parseArguments() -> CLIOptions? {
        var normalQuickPress = true
        var includeShift = false
        var keyMappingMode: KeyMappingMode = .capslock

        if CommandLine.arguments.contains("--version") {
            print("LazyKeys version \(version)")
            logger.info("LazyKeys version \(self.version)")
            exit(0)
        }

        if CommandLine.arguments.contains("--help") {
            printHelp()
            exit(0)
        }

        // Parse command line arguments
        var i = 1
        while i < CommandLine.arguments.count {
            let arg = CommandLine.arguments[i]

            switch arg {
            case "--no-quick-press":
                normalQuickPress = false
            case "--include-shift":
                includeShift = true
            case "--custom-key":
                // Get the next argument as the key code
                if i + 1 < CommandLine.arguments.count {
                    i += 1
                    let keyCodeString = CommandLine.arguments[i]
                    if let keyCode = parseKeyCode(keyCodeString) {
                        keyMappingMode = .custom(keyCode: keyCode)
                    } else {
                        print("Error: Invalid key code '\(keyCodeString)'")
                        logger.error("Error: Invalid key code '\(keyCodeString)'")
                        printKeyCodeHelp()
                        exit(1)
                    }
                } else {
                    print("Error: --custom-key requires a key code argument")
                    logger.error("Error: --custom-key requires a key code argument")
                    printKeyCodeHelp()
                    exit(1)
                }
            default:
                if arg.hasPrefix("-") {
                    print("Error: Unknown option '\(arg)'")
                    logger.error("Error: Unknown option '\(arg)'")
                    printHelp()
                    exit(1)
                }
            }
            i += 1
        }

        return CLIOptions(
            normalQuickPress: normalQuickPress,
            includeShift: includeShift,
            keyMappingMode: keyMappingMode
        )
    }

    private func printHelp() {
        print("""
        LazyKeys - Remap Caps Lock to useful keys

        Usage: lazykeys [OPTIONS]

        Options:
          --version                Show version information
          --no-quick-press         Disable quick press functionality
          --include-shift          Include Shift in Hyper key (Cmd+Ctrl+Alt+Shift)
          --custom-key <KEY>       Map Caps Lock to a custom key

        Key Mapping Modes:
          Default: Hyper Key mode (Cmd+Ctrl+Alt)
          --escape-mode: Quick press sends Escape
          --custom-key: Quick press sends specified key

        Examples:
          lazykeys                        # Hyper key with Caps Lock toggle on quick press
          lazykeys --custom-key escape    # Quick press sends Escape
          lazykeys --custom-key space     # Quick press sends Space
          lazykeys --custom-key return    # Quick press sends Return/Enter
          lazykeys --no-quick-press       # Only hold-down functionality, no quick press
        """)
        printKeyCodeHelp()
    }

    private func printKeyCodeHelp() {
        print("""

        Supported key names for --custom-key:
          space, return, enter, tab, delete, backspace, escape, esc
          f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12
          up, down, left, right
          home, end, pageup, pagedown
          Or use numeric key codes (0-127)
        """)
    }

    private func parseKeyCode(_ keyString: String) -> UInt8? {
        let lowercased = keyString.lowercased()

        // Handle named keys
        switch lowercased {
        case "space":
            return UInt8(kVK_Space)
        case "return", "enter":
            return UInt8(kVK_Return)
        case "tab":
            return UInt8(kVK_Tab)
        case "delete":
            return UInt8(kVK_Delete)
        case "backspace":
            return UInt8(kVK_ForwardDelete)
        case "escape", "esc":
            return UInt8(kVK_Escape)
        case "f1":
            return UInt8(kVK_F1)
        case "f2":
            return UInt8(kVK_F2)
        case "f3":
            return UInt8(kVK_F3)
        case "f4":
            return UInt8(kVK_F4)
        case "f5":
            return UInt8(kVK_F5)
        case "f6":
            return UInt8(kVK_F6)
        case "f7":
            return UInt8(kVK_F7)
        case "f8":
            return UInt8(kVK_F8)
        case "f9":
            return UInt8(kVK_F9)
        case "f10":
            return UInt8(kVK_F10)
        case "f11":
            return UInt8(kVK_F11)
        case "f12":
            return UInt8(kVK_F12)
        case "up":
            return UInt8(kVK_UpArrow)
        case "down":
            return UInt8(kVK_DownArrow)
        case "left":
            return UInt8(kVK_LeftArrow)
        case "right":
            return UInt8(kVK_RightArrow)
        case "home":
            return UInt8(kVK_Home)
        case "end":
            return UInt8(kVK_End)
        case "pageup":
            return UInt8(kVK_PageUp)
        case "pagedown":
            return UInt8(kVK_PageDown)
        default:
            // Try to parse as numeric key code
            if let numericCode = UInt8(keyString), numericCode <= 127 {
                return numericCode
            }
            return nil
        }
    }
}
