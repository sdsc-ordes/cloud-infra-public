{
  lib,
  config,
  pkgs,
  ...
}:
let
  signAllPackages = pkgs.writeShellScriptBin "sign-all-packages" ''
    ${pkgs.sudo}/bin/sudo ${pkgs.nix}/bin/nix store sign \
      --extra-experimental-features nix-command \
      --all --key-file ${config.sops.secrets.signingKey.path}
  '';

  inherit (config.settings.secrets) sshKeys;
in
{
  environment.systemPackages = [
    signAllPackages
  ];

  # Serving the Nix store.
  nix = {
    settings = {
      secret-key-files = [ config.sops.secrets.signingKey.path ];

      min-free = "5G";
      max-free = "80G";
    };

    gc = {
      automatic = lib.mkForce false;
    };

    sshServe = {
      enable = true;
      trusted = false;
      # All these keys have read access to the store.
      keys = sshKeys.users.nix-ssh;
    };
  };
}
