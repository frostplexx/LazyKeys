{ config, lib, pkgs, ... }:

let
  cfg = config.services.lazykeys;

lazykeys = pkgs.stdenv.mkDerivation {
  pname = "lazykeys";
  version = "v1.1.0";

  src = pkgs.fetchurl {
      url = "https://github.com/frostplexx/LazyKeys/releases/download/v1.1.0/lazykeys.tar.gz";
      hash = "sha256-finbc6UctXJLQifH2Lk0r7rQfYyO6D4nOTPNhz3vKFA=";
  };


  # Unpack in the installation phase because its just a binary inside and no folder to cd into
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    tar -xzf $src -C $out/bin 
    chmod +x $out/bin/lazykeys
    runHook postInstall
  '';

  meta = with lib; {
    description = "Remaps Caps Lock to useful keys (Hyper key, Escape, or custom keys)";
    license = licenses.mit;
    platforms = platforms.darwin;
  };

  __darwinAllowLocalNetworking = true;

  postInstall = ''
    echo "NOTE: lazykeys requires accessibility permissions."
    echo "      Please grant them in System Settings → Privacy & Security → Accessibility."
  '';
};

  launchAgentConfig = {
    ProgramArguments = 
      ["${lazykeys}/bin/lazykeys"]
      ++ (if !cfg.normalQuickPress then ["--no-quick-press"] else [])
      ++ (if cfg.includeShift then ["--include-shift"] else [])
      ++ (if cfg.mode == "escape" then ["--escape-mode"] 
          else if cfg.mode == "custom" then ["--custom-key" cfg.customKey]
          else []);
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    SessionCreate = true;
  };
in {
  options.services.lazykeys = {
    enable = lib.mkEnableOption "lazykeys service that remaps Caps Lock to useful keys";

    mode = lib.mkOption {
      type = lib.types.enum ["hyperkey" "escape" "custom"];
      default = "hyperkey";
      description = ''
        Key mapping mode:
        - hyperkey: Maps to Cmd+Ctrl+Alt (hyper key)
        - escape: Activates Escape instead of Caplock on quick press
        - custom: Activates a custom key specified by customKey instead of Caplock on quick press
      '';
    };

    customKey = lib.mkOption {
      type = lib.types.str;
      default = "escape";
      description = ''
        The key to map Caps Lock to when mode is "custom".
        Supported values: space, return, enter, tab, delete, backspace, escape, esc,
        f1-f12, up, down, left, right, home, end, pageup, pagedown, or numeric key codes (0-127).
      '';
    };

    normalQuickPress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If enabled, a quick press of the Caps Lock key will have special behavior:
        - In hyperkey mode: toggles Caps Lock state
        - In escape/custom mode: sends the mapped key
        If disabled, only hold-down behavior is active.
      '';
    };

    includeShift = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Only applies to hyperkey mode.
        If enabled, the Hyper key will include the Shift modifier (Cmd+Ctrl+Opt+Shift).
        If disabled, it will only include Cmd+Ctrl+Opt.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ lazykeys ];
    launchd.user.agents.lazykeys.serviceConfig = launchAgentConfig;
    
    # Add validation for custom mode
    assertions = [
      {
        assertion = cfg.mode != "custom" || cfg.customKey != "";
        message = "services.lazykeys.customKey must be set when mode is 'custom'";
      }
    ];
  };
}
