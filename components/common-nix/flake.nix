{
  description = "common-nix";
  inputs = {
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    vscode-server = {
      url = "github:nix-community/nixos-vscode-server";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Specific pinned version for the `zed-editor.remote_server`.
    nixpkgs-zed = {
      url = "github:nixos/nixpkgs/nixos-unstable";
    };
  };

  outputs = inputs: {
    homeManagerModules = import ./home { inherit (inputs) self; };
    nixosModules = import ./nixos { inherit (inputs) self; };
  };
}
