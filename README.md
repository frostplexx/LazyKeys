# LazyKeys


A Simple utility for macOS that remaps capslock to cmd+opt+ctrl (hyper key).


## Installation

### Homebrew

```bash
brew tap frostplexx/LazyKeys
brew install lazykeys
```


### Nix Flakes

Add
```nix
lazykeys = {
    url = "github:frostplexx/lazykeys";
};
```
to your inputs. Thenn add the nix module
```nix
modules = [
    inputs.lazykeys.darwinModules.default
];
```
Lastly enable the service using the following snippet in your `configruation.nix`:
```nix
services.lazykeys = {
    enable = true;
    normalQuickPress = true; # Quick press of Caps Lock will send Escape
    includeShift = false; # Hyper key will be Cmd+Ctrl+Alt (without Shift)
};
```
