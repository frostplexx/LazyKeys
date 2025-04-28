# LazyKeys

[![GitHub Release](https://img.shields.io/github/v/release/frostplexx/LazyKeys)](https://github.com/frostplexx/LazyKeys/releases)
[![Homebrew](https://img.shields.io/badge/homebrew-available-blue)](https://github.com/frostplexx/lazykeys)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

## Whats is This?

LazyKeys is a lightweight utility for macOS that remaps capslock to **Command + Option + Control**  (also called the hyper key).


## Installation

### Via Homebrew
```bash
# Add the tap and install in one go
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
    normalQuickPress = true;  # Quick press of Caps Lock will toggle capslock
    includeShift = false;     # Hyper key will be Cmd+Ctrl+Alt (without Shift)
};
```

## Usage

<!-- prettier-ignore -->
> :red_circle: **IMPORTANT**: **Restart lazykeys :exclamation:
> After first start lazykeys will ask for Accessibility Permission!
> After granting, you may need to **run `killall lazykeys` to restart it, otherwise it wont work 

### Basic Command
```bash
lazykeys                     # Run with default settings
lazykeys --no-quick-press    # Disable quick press to toggle Caps Lock
lazykeys --include-shift     # Include Shift in the Hyper key combo
lazykeys --version           # Display version information
```


### Run as a Service

#### With Homebrew
```bash
# Start the service (runs at login)
brew services start lazykeys

# Stop the service
brew services stop lazykeys

# Check status
brew services list
```

#### With AeroSpace
Add to your [AeroSpace](https://github.com/nikitabobko/AeroSpace) configuration by inserting this snippet in your `aerospace.toml`:

```yaml
after-startup-command = [
  'exec-and-forget lazykeys'
]
```

#### With Nix
Enable in your `configuration.nix` as shown in the installation section.


## Contributing

Contributions are welcome! Feel free to:
- Report bugs
- Suggest features
- Submit pull requests

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
