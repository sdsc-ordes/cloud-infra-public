{ lib, config, ... }:
let
  inherit (config.settings) secrets;

  usersSettings = lib.concatMapAttrs (username: keys: {
    # Must be a unique key.
    ${username} = {
      sshKeys = keys;

      vscodeServer.enable = true;
      zedServer.enable = true;
    };
  }) secrets.sshKeys.users;

in
{
  # These are our own settings (defined in `nixos/settings.nix`).
  settings = {
    users = usersSettings;

    root = {
      sshKeys = secrets.sshKeys.root;
    };

    ssh = {
      enable = true;
    };

    wireguard = {
      enable = true;
      tunnelIP = "10.10.50.1";
      peers.users = [
        "vancauwe"
      ];
    };

    timezone = "Europe/Zurich";
    hostName = "vm-ordes-main";
  };
}
