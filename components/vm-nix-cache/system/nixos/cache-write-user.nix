{
  config,
  pkgs,
  ...
}:
let
  command = "nix-store --serve --write";
  inherit (config.settings.secrets) sshKeys;
in
{
  # Add the write user settings.
  # Ref: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/misc/nix-ssh-serve.nix
  users = {
    users.nix-ssh-write = {
      description = "Nix SSH store user (write)";
      isSystemUser = true;
      group = "nix-ssh-write";
      shell = pkgs.bashInteractive;

      openssh.authorizedKeys.keys = sshKeys.users.nix-ssh-write;
    };
    groups.nix-ssh-write = { };
  };

  services.openssh.extraConfig = ''
    Match User nix-ssh-write
      AllowAgentForwarding no
      AllowTcpForwarding no
      PermitTTY no
      PermitTunnel no
      X11Forwarding no
      ForceCommand ${config.nix.package.out}/bin/${command}
    Match All
  '';

  # Serving the Nix Store.
  nix = {
    settings = {
      # The write user can do privileged operations (pushing to the cache etc.)
      trusted-users = [ "nix-ssh-write" ];
    };
  };
}
