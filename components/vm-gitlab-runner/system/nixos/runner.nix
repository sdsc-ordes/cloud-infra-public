# Gitlab Runner Module
#
# This module will add a Gitlab-Runner
# configured similar to https://wiki.nixos.org/wiki/Gitlab_runner
# with a nix-daemon running in a podman container `nix-daemon-container`.
#
# - The volumes from the `nix-daemon-container` will get mounted to
#   each job container which Gitlab starts, which gives them access
#   to a commonly shared Nix store.
#
#   - The `/nix/store` inside the job container
#     (either image `alpineImage` or `ubuntuImage` or `nixImage`)
#     will be read-only and nix can only store stuff into this path by using the
#     `NIX_DAEMON` env. variable which lets it communicate through the
#     mounted daemon socket.

#   - The `bootstrapPkgs` derivation is copied into the job containers
#     but without the Nix store paths cause they get provided by the
#     `nix-daemon-store` volume.
#
# - The `podman-daemon-socket` volume gets mounted to the job container
#   enabling it to use `podman`.
#   Note: The job container instance is not using the system `podman` running in NixOS.
#   Its a dedicated podman service `podmanDaemonContainer`
#   running as `--privileged`
#   [non-rootless container](https://rootlesscontaine.rs/#what-are-rootless-containers-and-what-are-not).
#   (TODO: This podman daemon instance could be maybe run as rootless
#   container under a user `ci` and a separated Gitlab Runner could
#   run over this socket, effectively run only rootless containers.)
#
# - There is also a job runner prebuild script which is started on every job.
#   See `scripts/prebuild.nix` to setup some missing stuff.
#
# Debugging on the VM:
#
# - You can use `journalclt -u gitlab-runner.service`.
# - Also inside `~/custodian` (clone this repo there)
#   you can run `cd tools/nix/vm && just vm::status`
#   to get some information about the
#   running stuff.
# - You can clean all logs with `journalclt --vacuume-time=1s`
# - Also you can run `btop` on the machine to inspect the performance.
# - To run a in a job container do `just vm run-job-container ...`
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # Either we use a Nix as the base image or Alpine.
  imageNames = {
    default = imageNames.alpine;

    alpine = "local/alpine";
    nix = "local/nix";
    ubuntu = "local/ubuntu";

    all = with imageNames; [
      alpine
      nix
      ubuntu
    ];
  };

  noPruneLabels = {
    no-prune = "true";
  };

  # Some scripts we use.
  updateNixStoreVolume = pkgs.callPackage ./scripts/copy-to-nix-store.nix {
    image = nixDaemonImage.imageName + ":" + nixDaemonImage.imageTag;
    imageDrv = nixDaemonImage;
  };

  # These derivations are symlinked into the job images root dir.
  jobImgs = import ./job-images.nix {
    inherit
      lib
      pkgs
      noPruneLabels
      imageNames
      ;
  };

  # Adding `nix-cache` as substituter to the nix-daemon
  # Needs a SSH key mounted in.
  extra-trusted-substituters = "ssh://nix-ssh@nix-cache.swisscustodian.ch";
  extra-trusted-public-keys = "nix-cache.swisscustodian.ch.1:rPQnp1nJav3UluO5MeomJTEPeqffeIu7Y41xpecBqMA=";
  sshConfig = pkgs.writeTextDir "config" ''
    Host nix-cache.swisscustodian.ch
      User nix-ssh
      IdentityFile ${config.sops.secrets.nix-cache-ssh-nix.path}
      StrictHostKeyChecking accept-new
  '';
  knownHosts = pkgs.writeTextDir "known_hosts" ''
    nix-cache.swisscustodian.ch ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMP4u5o2KC6f2OpO4b1GRQzhdcBheLENmS++xw1y5JvY
  '';

  # This is the Nix base image.
  nixDaemonImageBase = pkgs.callPackage (import (inputs.nix.outPath + "/docker.nix")) {
    name = "local/nix-base";
    tag = "latest";

    bundleNixpkgs = false;
    maxLayers = 2;

    nixConf = {
      cores = "0";
      experimental-features = [
        "nix-command"
        "flakes"
      ];

      secret-key-files = [ config.sops.secrets.nix-store-signing-key.path ];

      min-free = "1G"; # Triggers garbage collection.
      max-free = "100G"; # Stops garbage collection at 100G free space.

      # # Reduce disk usage by discarding old derivations/outputs
      # keep-derivations = false;
      # keep-outputs = false;

      inherit extra-trusted-public-keys extra-trusted-substituters;
    };
  };

  # This is the daemon image which provides the store
  # as volumes.
  nixDaemonImage = pkgs.dockerTools.buildLayeredImage {
    fromImage = nixDaemonImageBase;
    name = "local/nix-daemon";
    tag = "latest";

    fakeRootCommands =
      # bash
      ''
        mkdir -m 700 -p root/.ssh
        cp "${sshConfig}/config" root/.ssh/config
        chmod 600 root/.ssh/config
        cp "${knownHosts}/known_hosts" root/.ssh/known_hosts
        chmod 600 root/.ssh/known_hosts

        # Add all store paths and make them GC roots, so we dont loose them.
        # NOTE: Cannot add it to `extraPkgs` cause of the profile
        #       which uses `buildEnv` which collides.
         mkdir -p nix/var/nix/gcroots/additional-pkgs
         ${lib.concatMapStringsSep "\n" (pkg: ''
           echo "Adding package '${pkg}'"
           ln -fs "${pkg}" "nix/var/nix/gcroots/additional-pkgs/"
         '') jobImgs.allStoreDrv}
      '';

    config = {
      Volumes = {
        "/nix/store" = { };
        "/nix/var/nix/db" = { };
        "/nix/var/nix/daemon-socket" = { };
      };
      Labels = noPruneLabels;
    };
    maxLayers = 4;
  };

  # This is the podman daemon image which enables
  # a job image to use `podman` internally.
  podmanDaemonImage =
    let
      # Update with:
      # ```shell
      # nix run "github:nixos/nixpkgs/nixos-unstable#nix-prefetch-docker" -- \
      #    --image-name quay.io/podman/stable --image-tag v5.6.0
      # ```
      base = pkgs.dockerTools.pullImage {
        imageName = "quay.io/podman/stable";
        imageDigest = "sha256:7c9381b9af167cf2218831c3af3135856c99f488b543b78435c8f18e19ad739a";
        hash = "sha256-pXXCu13fB/RN9qx8iLhE5Kko6glTrFrRhR7fo2OS7V0=";
        finalImageName = "quay.io/podman/stable";
        finalImageTag = "v5.6.0";
      };
    in
    pkgs.dockerTools.buildLayeredImage {
      fromImage = base;
      name = "local/podman-daemon";
      tag = "latest";

      config = {
        Labels = noPruneLabels;
      };
    };

  nixDaemonContainer = {
    imageFile = nixDaemonImage;
    image = "local/nix-daemon:latest";

    volumes = [
      "nix-daemon-store:/nix/store"
      "nix-daemon-db:/nix/var/nix/db"
      "nix-daemon-socket:/nix/var/nix/daemon-socket"

      "${config.sops.secrets.nix-store-signing-key.path}:${config.sops.secrets.nix-store-signing-key.path}:ro"
      "${config.sops.secrets.nix-cache-ssh-nix.path}:${config.sops.secrets.nix-cache-ssh-nix.path}:ro"
    ];
    cmd = [
      "nix"
      "daemon"
    ];
  };

  podmanDaemonContainer = {
    imageFile = podmanDaemonImage;
    image = "local/podman-daemon:latest";
    volumes = [
      "podman-daemon-socket:/run/podman"
      "podman-cache:/var/lib/container"
      # Shared images, currently not needed.
      "podman-shared:/var/lib/shared:ro"
    ];
    privileged = true;
    cmd = [
      "podman"
      "system"
      "service"
      "--time=0"
      "unix:///run/podman/podman.sock"
      "--log-level"
      "info"
    ];
  };

  registrationFlags = [
    "--docker-volumes"
    "gitlab-runner-scratch:/scratch"

    "--docker-volumes"
    "podman-daemon-socket:/run/podman"

    "--docker-volumes-from"
    "nix-daemon-container:ro"

    "--docker-pull-policy"
    "if-not-present"

    "--docker-allowed-pull-policies"
    "if-not-present"

    "--docker-host"
    "unix:///var/run/podman/podman.sock"

    "--docker-network-mode"
    "bridge"
  ];

  # Workaround to add the job images to the registry.
  # On `nix` also make the scratch directory world readable.
  jobContainers = (
    lib.concatMapAttrs (name: image: {
      "${name}-container" = {
        imageFile = jobImgs.images.${name};
        image = "${imageNames.${name}}:latest";

        extraOptions = [
          "--volumes-from"
          "nix-daemon-container:ro"
        ];

        dependsOn = [ "nix-daemon-container" ];
        cmd = [ "true" ];
      }
      // (lib.optionalAttrs (name == "nix") {
        volumes = [ "gitlab-runner-scratch:/scratch" ];
        cmd = [
          "chmod"
          "777"
          "/scratch"
        ];
      });
    }) jobImgs.images
  );

  # Do not restart systemd service for the job images.
  modifiedJobServices = lib.concatMapAttrs (
    name: image:
    let
      serviceName = config.virtualisation.oci-containers.containers."${name}-container".serviceName;
    in
    {
      "${serviceName}".serviceConfig = {
        Restart = lib.mkForce "no";
      };
    }
  ) jobImgs.images;

in
{
  virtualisation.oci-containers = {
    backend = "podman";
    containers = jobContainers // {
      nix-daemon-container = nixDaemonContainer;
      podman-daemon-container = podmanDaemonContainer;
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
        inherit registrationFlags;

        authenticationTokenConfigFile = config.sops.secrets.gitlab-runner-custodian-token-config.path;

        executor = "docker";
        dockerImage = imageNames.default;
        dockerAllowedImages = [ ];
        dockerPrivileged = false;
        requestConcurrency = 4;

        preBuildScript = "${lib.getExe jobImgs.preBuildScript}";
      };

      services.nix-runner-bpa-docs = {
        description = "runner-bpa-docs";
        inherit registrationFlags;

        authenticationTokenConfigFile = config.sops.secrets.gitlab-runner-bpa-docs-token-config.path;

        executor = "docker";
        dockerImage = imageNames.default;
        dockerAllowedImages = imageNames.all;
        dockerPrivileged = false;
        requestConcurrency = 4;

        preBuildScript = "${lib.getExe jobImgs.preBuildScript}";
      };
    };
  };

  systemd.services = modifiedJobServices // {
    # Start 'nix-daemon-container' after the update of the volume.
    podman-nix-daemon-container.after = [ "update-nix-daemon-store.service" ];
    # Start Runner after nix-daemon-container.
    gitlab-runner.after = [ "podman-nix-daemon-container.service" ];

    # Update Nix store in the daemon service.
    update-nix-daemon-store = {
      description = "update-nix-daemon-store";
      restartIfChanged = true;

      wantedBy = [ "multi-user.target" ];

      # Ensure that the bootstrap is restarted when `nix-daemon-container` is.
      partOf = [ "podman-nix-daemon-container.service" ];

      script = ''
        ${lib.getExe updateNixStoreVolume}
      '';

      serviceConfig = {
        Type = "oneshot";
        SupplementaryGroups = "podman";
        User = "root";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };
  };
}
