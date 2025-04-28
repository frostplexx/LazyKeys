{ config, lib, pkgs, ... }:

let
  cfg = config.services.lazykeys;

lazykeys = pkgs.stdenv.mkDerivation {
  pname = "lazykeys";
  version = "v0.0.1";

  src = pkgs.fetchurl {
      url = "https://github.com/frostplexx/LazyKeys/releases/download/v0.0.1/lazykeys.tar.gz";
      hash = "sha256-mMs7ONmJmm6Jc3u8u0BPn2d9WGh91m7LMJRc9Yl5Uhk=";
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
    description = "Remaps Caps Lock to a Hyper key";
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
    ProgramArguments = [
      "${lazykeys}/bin/lazykeys"
    ]
    ++ (if !cfg.normalQuickPress then ["--no-quick-press"] else [])
    ++ (if cfg.includeShift then ["--include-shift"] else []);
    RunAtLoad = true;
    KeepAlive = true;
    EnvironmentVariables = {
        PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
    };
    SessionCreate = true;
  };
in {
  options.services.lazykeys = {
    enable = lib.mkEnableOption "lazykeys service that remaps Caps Lock to a Hyper key";

    normalQuickPress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        If enabled, a quick press of the Caps Lock key will send an Escape key.
        If disabled, it will only act as the Hyper key.
      '';
    };

    includeShift = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If enabled, the Hyper key will include the Shift modifier (Cmd+Ctrl+Opt+Shift).
        If disabled, it will only include Cmd+Ctrl+Opt.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ lazykeys ];
    launchd.user.agents.lazykeys.serviceConfig = launchAgentConfig;
  };
}
