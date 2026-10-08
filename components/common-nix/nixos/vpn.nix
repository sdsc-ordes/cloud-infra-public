{ config, lib, ... }:
let
  cfg = config.settings;
in
{
  config = lib.mkIf cfg.wireguard.enable {

    sops.secrets.wireguard-private-key = {
      sopsFile = cfg.secrets.wireguard.server.privateKey;
      format = "binary";
      # For permission, see man systemd.netdev.
      mode = "640";
      owner = "systemd-network";
      group = "systemd-network";
    };

    networking = {
      firewall.allowedUDPPorts = [ 51820 ];
      useNetworkd = true;
    };

    systemd.network = {
      enable = true;

      # Wireguard tunnel.
      networks."50-wg0" = {
        matchConfig.Name = "wg0";

        address = [
          # The /32 and /128 specifies a single address
          # for use on this wg peer machine.
          "${config.settings.wireguard.tunnelIP}/32"
        ];
      };

      # Wireguard device.
      netdevs."50-wg0" = {
        netdevConfig = {
          Kind = "wireguard";
          Name = "wg0";
        };

        wireguardConfig = {
          ListenPort = 51820;

          # ensure file is readable by `systemd-network` user
          PrivateKeyFile = config.sops.secrets.wireguard-private-key.path;

          # To automatically create routes for everything in AllowedIPs,
          # add RouteTable=main
          RouteTable = "main";

          # FirewallMark marks all packets send and received by wg0
          # with the number 42, which can be used to define policy rules on these packets.
          FirewallMark = 42;
        };

        wireguardPeers =
          let
            allPeers = lib.sort (a: b: a.ipIndex < b.ipIndex) (
              cfg.secrets.wireguard.getPeers {
                componentName = cfg.hostName;
                userNames = cfg.wireguard.peers.users;
              }
            );
          in
          lib.imap (
            idx: peer:
            let
              s = lib.concatStringsSep "." (lib.sublist 0 3 (lib.splitString "." cfg.wireguard.tunnelIP));
            in
            {
              PublicKey = peer.publicKey;
              # We fix the IP for this peer. Start at 2, cause the server is `.1`.
              AllowedIPs = [ "${s}.${toString (peer.ipIndex + 2)}/32" ];
            }
          ) allPeers;
      };
    };
  };
}
