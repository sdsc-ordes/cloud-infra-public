{
  lib,
  config,
  pkgs,
  ...
}:
{
  # Add users to groups.
  users.users = lib.concatMapAttrs (username: cfg: {
    ${username}.extraGroups = [
      "docker"
      "podman"
      "libvirtd"
    ];
  }) config.settings.users;

  # Disable docker!
  virtualisation.docker = {
    enable = false;
  };

  virtualisation.podman = {
    enable = true;

    # Create a `docker` alias for podman, to use it as a drop-in replacement
    # dockerCompat = true;
    dockerSocket = {
      enable = true;
    };

    # Required for containers under podman-compose to be able to talk to each other.
    defaultNetwork.settings.dns_enabled = true;

    autoPrune = {
      dates = "weekly";
      flags = [
        "--filter"
        "label!=no-prune"
        "--volumes"
        "--log-level"
        "debug"
      ];
    };
  };

  environment.systemPackages = [
    pkgs.podman
    pkgs.docker-compose
  ];

  # Enabling `/etc/containers` configuration module.
  virtualisation.containers = {
    enable = true;

    # Use `crun` which is the defactor std on most distros,
    # - `runc` is the Go tool
    containersConf.settings = {
      engine.runtimes = [ "crun" ];
    };

    storage.settings = {
      storage = {
        driver = "overlay";
        graphroot = "/var/lib/containers/storage";
        runroot = "/run/containers/storage";

        # Does not work currently.
        options.overlay = {
          mountopt = "nodev,metacopy=on";
        };
      };
    };
  };
}
