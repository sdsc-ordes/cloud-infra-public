{ config, ... }:
{
  services.qemuGuest.enable = true;

  services.openssh = {
    enable = config.settings.ssh.enable;

    openFirewall = true;
    settings = {
      ClientAliveInterval = 60;
      ClientAliveCountMax = 3;
    };
  };
}
