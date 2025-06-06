# LazyKeys

[![GitHub Release](https://img.shields.io/github/v/release/frostplexx/LazyKeys)](https://github.com/frostplexx/LazyKeys/releases)
[![Build and Publish LazyKeys](https://github.com/frostplexx/LazyKeys/actions/workflows/build_and_publish.yml/badge.svg)](https://github.com/frostplexx/LazyKeys/actions/workflows/build_and_publish.yml)
[![Homebrew](https://img.shields.io/badge/homebrew-available-blue)](https://github.com/frostplexx/lazykeys)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## What is This?

LazyKeys is a lightweight utility for macOS that remaps Caps Lock to more useful keys. It supports multiple mapping modes:

- **Hyper Key Mode** (default): Remaps Caps Lock to **Command + Option + Control** (the hyper key)
- **Escape Mode**: Maps Caps Lock to the Escape key
- **Custom Key Mode**: Maps Caps Lock to any key you specify

## Features

- 🎯 **Multiple Key Mapping Modes**: Hyper key, Escape, or any custom key
- ⚡ **Quick Press Detection**: Different behavior for quick press vs hold
- 🔧 **Configurable Options**: Include Shift modifier, disable quick press
- 🚀 **Lightweight**: Minimal resource usage
- 🔒 **Native macOS Integration**: Uses system-level key remapping

## Installation

### Via Homebrew
```bash
brew tap frostplexx/tap
brew install lazykeys
```

### Using Nix Flakes
1. Add to your inputs:
```nix
lazykeys = {
    url = "github:frostplexx/lazykeys";
};
```

2. Add the nix module:
```nix
modules = [
    inputs.lazykeys.darwinModules.default
];
```

3. Enable the service in your `configuration.nix`:
```nix
services.lazykeys = {
    enable = true;
    normalQuickPress = true;  # Quick press behavior
    includeShift = false;     # Hyper key will be Cmd+Ctrl+Alt (without Shift)
    mode = "hyperkey";        # or "escape" or "custom"
    customKey = "space";      # Only needed for custom mode
};
```

## Usage

### Command Line Options

```bash
# Show help and available options
lazykeys --help

# Basic usage (Hyper Key mode)
lazykeys                     # Default: Caps Lock → Hyper Key (Cmd+Ctrl+Alt)
lazykeys --include-shift     # Hyper Key includes Shift (Cmd+Ctrl+Alt+Shift)


# Custom key mode
lazykeys --custom-key space     # Quick press → Space
lazykeys --custom-key escape    # Quick press → Escape
lazykeys --custom-key return    # Quick press → Return/Enter
lazykeys --custom-key f1        # Quick press → F1
lazykeys --custom-key 53        # Quick press → Key code 53 (Escape)

# Additional options
lazykeys --no-quick-press    # Disable quick press, only hold behavior
lazykeys --version           # Show version information
```

### Key Mapping Modes

#### Default
- **Hold Caps Lock**: Acts as Cmd+Ctrl+Alt (+ Shift if `--include-shift`)
- **Quick Press**: Toggles Caps Lock state (if `--no-quick-press` not used)

#### Custom Key Mode (`--custom-key <KEY>`)
- **Quick Press**: Sends the specified key
- **Hold**: Acts as Cmd+Ctrl+Alt

### Supported Key Names

For `--custom-key` option, you can use:

**Special Keys:**
- `space`, `return`, `enter`, `tab`, `delete`, `backspace`, `escape`, `esc`

**Function Keys:**
- `f1`, `f2`, `f3`, `f4`, `f5`, `f6`, `f7`, `f8`, `f9`, `f10`, `f11`, `f12`

**Arrow Keys:**
- `up`, `down`, `left`, `right`

**Navigation Keys:**
- `home`, `end`, `pageup`, `pagedown`

**Numeric Key Codes:**
- Any number from 0-127 (e.g., `53` for Escape)

### Run as a Service

#### With Homebrew
```bash
# Start the service (runs at login)
brew services start lazykeys

# Stop the service
brew services stop lazykeys

# Check status
brew services list

# Start with custom options (you'll need to create a custom plist)
# See "Custom Service Configuration" section below
```

#### With AeroSpace
Add to your [AeroSpace](https://github.com/nikitabobko/AeroSpace) configuration by inserting this snippet in your `aerospace.toml`:

```yaml
after-startup-command = [
  'exec-and-forget lazykeys --escape-mode'  # or your preferred options
]
```

#### With Nix
Enable in your `configuration.nix` as shown in the installation section.

### Custom Service Configuration

To run LazyKeys as a service with custom options, create a LaunchAgent plist file:

```bash
# Create the directory if it doesn't exist
mkdir -p ~/Library/LaunchAgents

# Create the plist file
cat > ~/Library/LaunchAgents/com.lazykeys.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.lazykeys</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/lazykeys</string>
        <string>--escape-mode</string>
        <!-- Add more arguments as needed -->
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# Load the service
launchctl load ~/Library/LaunchAgents/com.lazykeys.plist

# Unload if needed
launchctl unload ~/Library/LaunchAgents/com.lazykeys.plist
```

## Troubleshooting

### Accessibility Permissions
1. Go to **System Settings** → **Privacy & Security** → **Accessibility**
2. Add LazyKeys to the list and enable it
3. Restart LazyKeys by killing the process: `killall lazykeys`

### Key Mapping Not Working
- Ensure you've granted Accessibility permissions
- Try restarting LazyKeys after permission changes (`pkill lazykeys`)
- Check if other key remapping software is conflicting
- Make sure F18 isn't mapped to something else
- If more than one instance of LazyKeys is running (check with `ps aux |grep lazykeys`) kill every other instance and restart the remaining one

## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
