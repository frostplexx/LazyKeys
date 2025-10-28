//
//  CLIParser.swift
//  LazyKeys
//
//  Purpose: Parses command-line arguments and provides user-friendly help output.
//           Converts user input into structured configuration options for the application.
//

import Carbon
import Foundation
import os.log

// MARK: - CLIOptions Structure

/// Configuration options parsed from command-line arguments.
///
/// This structure encapsulates all user-configurable settings that control
/// the behavior of the LazyKeys application.
struct CLIOptions {
    /// Whether quick press functionality is enabled.
    /// - If `true`: Quick press triggers the configured action (Caps Lock toggle or custom key)
    /// - If `false`: Only hold-down behavior (Hyper key) is active
    let normalQuickPress: Bool

    /// Whether to include Shift in the Hyper key combination.
    /// - If `true`: Hyper key = Cmd+Ctrl+Alt+Shift
    /// - If `false`: Hyper key = Cmd+Ctrl+Alt
    let includeShift: Bool

    /// The key mapping mode that determines quick press behavior.
    let keyMappingMode: KeyMappingMode
}

// MARK: - CLIParser Class

/// Parses and validates command-line arguments for LazyKeys.
///
/// This class is responsible for:
/// - Processing command-line flags and options
/// - Validating user input
/// - Providing helpful error messages and usage information
/// - Converting key names to virtual key codes
///
/// The parser supports various flags for customizing behavior and provides
/// comprehensive help output for users.
class CLIParser {
    // MARK: - Properties

    /// Application version string (injected at compile time via VERSION_STRING macro)
    private let version = String(cString: VERSION_STRING)

    /// Logger for tracking argument parsing and errors
    private let logger = Logger(subsystem: "com.frostplexx.lazykeys", category: "CLIParser")

    // MARK: - Public Methods

    /// Parses command-line arguments into structured configuration options.
    ///
    /// This method processes all command-line arguments and converts them into
    /// a `CLIOptions` structure. It handles special cases like `--version` and
    /// `--help` by printing information and exiting.
    ///
    /// Supported flags:
    /// - `--version`: Display version and exit
    /// - `--help`: Display help message and exit
    /// - `--no-quick-press`: Disable quick press functionality
    /// - `--include-shift`: Add Shift to Hyper key combination
    /// - `--custom-key <KEY>`: Map quick press to a custom key
    ///
    /// - Returns: A `CLIOptions` structure with the parsed configuration,
    ///            or `nil` if parsing failed (though most failures result in exit)
    func parseArguments() -> CLIOptions? {
        // Default configuration values
        var normalQuickPress = true
        var includeShift = false
        var keyMappingMode: KeyMappingMode = .capslock

        // Handle special flags that display information and exit
        if CommandLine.arguments.contains("--version") {
            print("LazyKeys version \(version)")
            logger.info("LazyKeys version \(self.version)")
            exit(0)
        }

        if CommandLine.arguments.contains("--help") {
            printHelp()
            exit(0)
        }

        // Parse all command-line arguments
        // Start at index 1 to skip the executable name (CommandLine.arguments[0])
        var i = 1
        while i < CommandLine.arguments.count {
            let arg = CommandLine.arguments[i]

            switch arg {
            case "--no-quick-press":
                // Disable quick press - only Hyper key hold behavior will work
                normalQuickPress = false

            case "--include-shift":
                // Add Shift to the Hyper key combination
                includeShift = true

            case "--custom-key":
                // Parse custom key mapping - requires an additional argument
                if i + 1 < CommandLine.arguments.count {
                    i += 1 // Move to the next argument
                    let keyCodeString = CommandLine.arguments[i]

                    if let keyCode = parseKeyCode(keyCodeString) {
                        // Successfully parsed key code
                        keyMappingMode = .custom(keyCode: keyCode)
                    } else {
                        // Invalid key code provided
                        print("Error: Invalid key code '\(keyCodeString)'")
                        logger.error("Error: Invalid key code '\(keyCodeString)'")
                        printKeyCodeHelp()
                        exit(1)
                    }
                } else {
                    // Missing required argument for --custom-key
                    print("Error: --custom-key requires a key code argument")
                    logger.error("Error: --custom-key requires a key code argument")
                    printKeyCodeHelp()
                    exit(1)
                }

            default:
                // Handle unknown flags
                if arg.hasPrefix("-") {
                    print("Error: Unknown option '\(arg)'")
                    logger.error("Error: Unknown option '\(arg)'")
                    printHelp()
                    exit(1)
                }
                // Non-flag arguments are silently ignored
            }

            i += 1
        }

        // Return the parsed configuration
        return CLIOptions(
            normalQuickPress: normalQuickPress,
            includeShift: includeShift,
            keyMappingMode: keyMappingMode
        )
    }

    // MARK: - Private Methods

    /// Prints comprehensive help information about LazyKeys usage.
    ///
    /// Displays:
    /// - Brief description
    /// - Usage syntax
    /// - Available options and flags
    /// - Key mapping modes
    /// - Practical examples
    /// - Supported key names
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

    /// Prints a list of supported key names for the `--custom-key` option.
    ///
    /// This includes:
    /// - Common special keys (space, return, tab, etc.)
    /// - Function keys (F1-F12)
    /// - Arrow keys
    /// - Navigation keys (home, end, pageup, pagedown)
    /// - Numeric key codes (0-127)
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

    /// Converts a key name string to its corresponding virtual key code.
    ///
    /// This method supports:
    /// - Named keys (e.g., "space", "escape", "f1")
    /// - Aliases (e.g., "enter" for "return", "esc" for "escape")
    /// - Numeric key codes (0-127)
    ///
    /// The comparison is case-insensitive for convenience.
    ///
    /// - Parameter keyString: The key name or numeric code as a string
    /// - Returns: The corresponding virtual key code as `UInt8`, or `nil` if invalid
    private func parseKeyCode(_ keyString: String) -> UInt8? {
        let lowercased = keyString.lowercased()

        // Map named keys to their virtual key codes using Carbon's constants
        switch lowercased {
        // Basic keys
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

        // Function keys (F1-F12)
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

        // Arrow keys
        case "up":
            return UInt8(kVK_UpArrow)
        case "down":
            return UInt8(kVK_DownArrow)
        case "left":
            return UInt8(kVK_LeftArrow)
        case "right":
            return UInt8(kVK_RightArrow)

        // Navigation keys
        case "home":
            return UInt8(kVK_Home)
        case "end":
            return UInt8(kVK_End)
        case "pageup":
            return UInt8(kVK_PageUp)
        case "pagedown":
            return UInt8(kVK_PageDown)

        default:
            // Attempt to parse as a numeric key code (0-127 are valid virtual key codes)
            if let numericCode = UInt8(keyString), numericCode <= 127 {
                return numericCode
            }
            // Invalid key name or out of range numeric code
            return nil
        }
    }
}
