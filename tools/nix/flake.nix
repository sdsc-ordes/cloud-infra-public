{
  description = "switch-cloud-infra";

  nixConfig = {
    extra-substituters = [ ];
  };

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
    };

    # Format the repo with nix-treefmt.
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Nushell formatter.
    nufmt = {
      url = "github:nushell/nufmt";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }@inputs:
    let

      # The function which builds the flake output attrMap.
      defineOutput =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          lib = nixpkgs.lib;

          treefmt = (import ./packages/treefmt.nix { inherit inputs pkgs; });

          nufmt = inputs.nufmt.packages.${system}.nufmt;

          sopsGenCfg =
            pkgs.writeShellScriptBin "sops-gen-cfg"
              # bash
              ''
                set -eu -o pipefail
                root_dir=$(git rev-parse --show-toplevel)
                "${lib.getExe pkgs.ytt}" \
                  -f "$root_dir/components/secrets/_ytt_lib" \
                  -f "$root_dir/components/secrets/secrets.yaml" \
                  > "$1"
                echo "Set 'SOPS_CONFIG=$1'." 2>/dev/null
              '';

          sopsWithCfg =
            pkgs.writeShellScriptBin "sops"
              # bash
              ''
                set -eu -o pipefail
                sops_secrets_file=$(mktemp --suffix .yaml)
                trap 'rm "$sops_secrets_file"' EXIT
                root_dir=$(git rev-parse --show-toplevel)

                "${lib.getExe sopsGenCfg}" "$sops_secrets_file"
                "${pkgs.sops}/bin/sops" --config "$sops_secrets_file" "$@"
              '';

          basicsPkgs = [
            pkgs.bash
            pkgs.coreutils
            pkgs.curl
            pkgs.entr
            pkgs.fd
            pkgs.git
            pkgs.gitleaks
            pkgs.jq
            pkgs.just
            pkgs.nushell
            pkgs.prek
            treefmt
            nufmt
            pkgs.yq-go
            pkgs.zsh
            pkgs.ytt

            pkgs.upterm
            pkgs.tmate
          ];

          deployPkgs = [
            pkgs.age
            pkgs.ragenix
            pkgs.deploy-rs
            pkgs.findutils
            pkgs.nixos-anywhere
            pkgs.openstackclient
            pkgs.opentofu

            pkgs.cmctl # Utility to interact with the cert-manager in k8s.
            pkgs.k9s
            pkgs.flux9s
            pkgs.kubectl
            pkgs.kubectl-cnpg # Postgres kubectl plugin.
            pkgs.kubernetes-helm # Render/inspect the charts flux deploys.
            pkgs.fluxcd # `flux` CLI: reconcile, diff, get, logs.
            pkgs.kustomize
            pkgs.kubelogin-oidc # OIDC Login for k8 credentials.

            pkgs.wireguard-tools

            sopsWithCfg
            sopsGenCfg
            pkgs.ssh-to-age
          ];

        in
        {
          packages = {
            inherit treefmt;
          };

          devShells = {
            default = pkgs.mkShell {
              packages = basicsPkgs ++ deployPkgs;
              CLOUDINFRA_IN_DEVSHELL = true;
              shellHook = ''
                set -eu -o pipefail
                # Config symlinks first: prek reads .pre-commit-config.yaml.
                just setup
                prek install || { echo "Could not install prek."; }
              '';
            };
          };
        };
    in
    # Creates an attribute map `{ <key>.<system>.default = ...}`
    # by calling function `defineOutput`.
    # Key sofar is only `devShells` but can be any output `key` for a flake.
    flake-utils.lib.eachDefaultSystem defineOutput;
}
