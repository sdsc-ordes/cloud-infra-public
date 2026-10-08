{ self }:
# Search for all options using: https://mipmip.github.io/home-manager-option-search
{ ... }:
{
  imports = [
    ./shell.nix
    ./session.nix
    ./tmux.nix
    (import ./vscode.nix { inherit (self.inputs) vscode-server; })

    (import ./zed.nix {
      inherit (self.inputs) nixpkgs-zed;
    })
  ];

  # Enable home-manager.
  programs.home-manager.enable = true;

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "25.11";
}
