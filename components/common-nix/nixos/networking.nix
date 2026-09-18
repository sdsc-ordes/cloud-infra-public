{ config, ... }:
{
  networking = {
    useNetworkd = true;

    enableIPv6 = true;

    # Open ports in the firewall.
    firewall = {
      enable = true;
    };

    hostName = config.settings.hostName;
  };

  boot.kernel.sysctl = {
    "net.ipv6.conf.all.accept_ra" = 1;
    "net.ipv6.conf.default.accept_ra" = 1;
    "net.ipv6.conf.all.forwarding" = 0;
  };

  systemd.network = {
    enable = true;

    networks."10-wired" = {
      matchConfig.Name = [
        "en*"
        "eth*"
      ];

      networkConfig = {
        DHCP = "yes";
        DNSDefaultRoute = true;

        # When a router advertisement (RA) is received,
        # the interface will get a dynamic IP configuration via DHCP.
        IPv6AcceptRA = true; # Accept router advertisement.
        LinkLocalAddressing = true; # Required for RA.
      };

      linkConfig = {
        Multicast = true; # Required for RA.
      };
    };
  };

  # Same as default Ubuntu VM.
  services.resolved = {
    enable = true;

    fallbackDns = [
      # Switch DNS
      "130.59.31.248"
      "130.59.31.251"
      "2001:620:0:ff::2"
      "2001:620:0:ff::3"

      # Cloudflare
      "1.1.1.1"
      "2606:4700:4700::1111"
      "2606:4700:4700::1001"

      # Google
      "8.8.8.8"
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
    ];

    llmnr = "false";
    dnsovertls = "false";
    dnssec = "false";
  };
}
