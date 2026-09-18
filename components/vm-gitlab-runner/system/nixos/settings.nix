{ lib, config, ... }:
let
  inherit (config.settings) secrets;

  usersSettings = lib.concatMapAttrs (username: keys: {
    # Must be a unique key.
    ${username} = {
      sshKeys = keys;
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
      tunnelIP = "10.20.50.1";
    };

    timezone = "Europe/Zurich";
    hostName = "vm-gitlab-runner";

    extraZshrc =
      # bash
      ''
        dir="$HOME/cloud-infra/components/vm-gitlab-runner/system"
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
