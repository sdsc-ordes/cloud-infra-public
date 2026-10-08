{ lib, config, ... }:
let
  inherit (config.settings) secrets;
in
{
  # These are our own settings (defined in `nixos/settings.nix`).
  settings = {
    users = {
      # No users with defaults.
    };

    root = {
      sshKeys = secrets.sshKeys.root;
    };

    ssh = {
      enable = true;
    };

    wireguard = {
      enable = false;
    };

    autoUpgrade = {
      enable = true;
    };

    timezone = "Europe/Zurich";
    hostName = "vm-nix-cache";

    extraZshrc =
      # bash
      ''
        dir="$HOME/cloud-infra/components/vm-nix-cache/system"
        if [ -d "$dir" ]; then
          cd "$dir"
        else
          echo "No '$dir' to switch to."
        fi
        # ----------------------------------

        if [ -z "$TMUX" ]; then
          tmux new-session -d -s 1 || true
          exec tmux attach -t 1
        fi
      '';
  };

}
