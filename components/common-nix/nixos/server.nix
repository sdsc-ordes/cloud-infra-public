{ lib, ... }:
# Ref: https://github.com/nix-community/srvos/blob/main/nixos/server/default.nix
{
  # No need for fonts on a server
  fonts.fontconfig.enable = lib.mkDefault false;

  environment = {
    # Print the URL instead on servers
    variables.BROWSER = "echo";
  };

  # Freedesktop xdg files.
  xdg.autostart.enable = lib.mkDefault false;
  xdg.icons.enable = lib.mkDefault false;
  xdg.menus.enable = lib.mkDefault false;
  xdg.mime.enable = lib.mkDefault false;
  xdg.sounds.enable = lib.mkDefault false;

  # Make sure firewall is enabled.
  networking.firewall.enable = true;

  # No mutable users by default.
  users.mutableUsers = false;

  security.sudo.wheelNeedsPassword = false;

  systemd = {
    # Given that our systems are headless, emergency mode is useless.
    # We prefer the system to attempt to continue booting so
    # that we can hopefully still access it remotely.
    enableEmergencyMode = false;

    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
    '';

    # # For more detail, see:
    # #   https://0pointer.de/blog/projects/watchdog.html
    # settings.Manager = {
    #   # systemd will send a signal to the hardware watchdog at half
    #   # the interval defined here, so every 7.5s.
    #   # If the hardware watchdog does not get a signal for 15s,
    #   # it will forcefully reboot the system.
    #   RuntimeWatchdogSec = lib.mkDefault "15s";
    #   # Forcefully reboot if the final stage of the reboot
    #   # hangs without progress for more than 30s.
    #   # For more info, see:
    #   #   https://utcc.utoronto.ca/~cks/space/blog/linux/SystemdShutdownWatchdog
    #   RebootWatchdogSec = lib.mkDefault "30s";
    #   # Forcefully reboot when a host hangs after kexec.
    #   # This may be the case when the firmware does not support kexec.
    #   KExecWatchdogSec = lib.mkDefault "1m";
    # };
  };

  # Make sure the serial console is visible in qemu when testing the server configuration
  # with nixos-rebuild build-vm
  virtualisation.vmVariant.virtualisation.graphics = lib.mkDefault false;
}
