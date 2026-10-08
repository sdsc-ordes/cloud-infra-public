{ pkgs, lib, ... }:
{
  # Packages
  environment.systemPackages = with pkgs; [
    # Essentials.
    coreutils
    findutils
    zsh
    curl
    gitFull

    # Useful VM tool.s
    jq
    btop
    tree
    neovim
    tmux
    just

    # Net utils.
    dig
    traceroute
    nmap
  ];

  programs = {
    zsh.enable = true;

    git = {
      enable = true;
      package = pkgs.gitFull;
      # Do not use libsecret on VM, but store secrets in mem.
      config.credential.helper = "cache";
    };
  };
}
