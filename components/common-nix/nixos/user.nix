{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Define user settings for `cfg = config.settings.users.<name>`
  defineUserSettings = username: cfg: {
    ${username} = {
      shell = pkgs.zsh;

      createHome = true;

      linger = true; # Start systemd units at boot, rather than at login.
      useDefaultShell = false;

      isNormalUser = true;

      extraGroups = [
        "disk"
        "network"
        "systemd-journal"
      ];

      openssh.authorizedKeys.keys = cfg.sshKeys;
    }
    # Extent the user `uid/gid` ranges to make podman work better.
    # This for rootless podman and also nested podman inside a rootless one.
    // lib.optionalAttrs config.virtualisation.podman.enable {
      subUidRanges = [
        {
          startUid = 100000;
          count = 65539;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65539;
        }
      ];
    };
  };
in
{
  ### User Settings ==========================================================
  users.users = {
    root = {
      shell = pkgs.zsh;
      useDefaultShell = false;
      isSystemUser = true;
      openssh.authorizedKeys.keys = config.settings.root.sshKeys;
    };
  }
  // lib.concatMapAttrs (username: cfg: defineUserSettings username cfg) config.settings.users;
  # ===========================================================================
}
