{
  description = "vm-ordes-main";

  nixConfig = {
    extra-trusted-substituters = [ ];
    extra-trusted-public-keys = [ ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs = {
      url = "github:nixos/nixpkgs/nixos-25.11";
    };

    # Encrypted secrets.
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Declarative Disk partitioning for VMs.
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    deploy-rs = {
      url = "github:serokell/deploy-rs";
    };

    # Home-Manager for NixOS.
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    common-nix = {
      url = "path:../../common-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    secrets = {
      url = "path:../../secrets";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    let
      inherit (inputs.self) outputs;
      vm-ordes-main = import ./nixos { inherit inputs outputs; };

      nixosConfigurations = {
        inherit vm-ordes-main;
      };

      deploy = {
        nodes.vm-ordes-main = {
          hostname = "vm-ordes-main";
          fastConnection = true;
          profiles = {
            system = {
              user = "root";
              sshUser = "root";
              path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos vm-ordes-main;
            };
          };
        };
      };
    in
    {
      inherit nixosConfigurations deploy;
    };
}
