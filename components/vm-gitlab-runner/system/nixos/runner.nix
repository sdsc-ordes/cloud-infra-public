{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.gitlab-runner-podman;

  # Adding `nix-cache` as substituter to the nix-daemon
  extra-trusted-substituters = "https://nix-cache.sck-sit-dev.dscompute.ch";
  extra-trusted-public-keys = "nix-cache:lVTYyJ3CTjHRnuhxA5APy9jrdZGdfyuxKOwU7lKihZE=";
  netrc-file = config.sops.secrets.nix-cache-netrc-file.path;
in
{
  imports = [
    inputs.nixos-gitlab-runner.nixosModules.gitlab-runner-podman
  ];

  # Enable the job images, the Nix daemon container and the podman daemon
  # container. The runner below is configured against them.
  services.gitlab-runner-podman = {
    enable = true;

    # Prune containers, images and volumes which are not labeled `no-prune`
    # once a day. All images built by this module carry that label.
    autoPrune.enable = true;

    nix-daemon = {
      nixConf = {
        inherit extra-trusted-substituters extra-trusted-public-keys netrc-file;
        secret-key-files = [ config.sops.secrets.nix-store-signing-key.path ];
      };
    };

    jobs = {
      packagesFunc =
        { pkgs, defaultPackages, ... }:
        [
          pkgs.just
          pkgs.cachix
        ]
        ++ defaultPackages;
    };
  };

  virtualisation.oci-containers.containers = {
    nix-daemon-container = {
      volumes = [
        "${config.sops.secrets.nix-store-signing-key.path}:${config.sops.secrets.nix-store-signing-key.path}:ro"
        "${config.sops.secrets.nix-cache-netrc-file.path}:${config.sops.secrets.nix-cache-netrc-file.path}:ro"
      ];
    };
  };

  services = {
    # Define the Gitlab Runner.
    gitlab-runner = {
      enable = true;

      settings = {
        log_level = "info";
        # See https://stackoverflow.com/a/55173132/293195
        concurrent = 32;

        check_interval = 2;
      };

      gracefulTermination = false;

      # Registered with Tags `nix, linux`.
      services.nix-runner = {
        description = "runner-custodian"; # Do not write here crazy characters due to systemd script.
        inherit (cfg) registrationFlags;

        authenticationTokenConfigFile = config.sops.secrets.gitlab-runner-custodian-token-config.path;

        executor = "docker";
        dockerImage = cfg.jobs.defaultImageName;
        dockerAllowedImages = [ ];
        dockerPrivileged = false;
        requestConcurrency = 4;

        preBuildScript = "${lib.getExe cfg.preBuildScript}";
      };

      services.nix-runner-bpa-docs = {
        description = "runner-bpa-docs";
        inherit (cfg) registrationFlags;

        authenticationTokenConfigFile = config.sops.secrets.gitlab-runner-bpa-docs-token-config.path;

        executor = "docker";
        dockerImage = cfg.jobs.defaultImageName;
        dockerAllowedImages = [ ];
        dockerPrivileged = false;
        requestConcurrency = 4;

        preBuildScript = "${lib.getExe cfg.preBuildScript}";
      };
    };
  };
}
