{
  lib,
  ...
}:
let
  port = 22222;
in
{
  containers.tmate = {
    autoStart = true;

    # Create a VETH pair
    privateNetwork = true;
    hostAddress = "10.0.0.1";
    localAddress = "10.0.0.2";

    # Tmate needs CAP_SYS_ADMIN to create the nested namespaces that
    # isolate each session. nspawn drops it by default — grant it back
    # or tmate-ssh-server exits immediately.
    additionalCapabilities = [ "CAP_SYS_ADMIN" ];

    config = {
      system.stateVersion = lib.trivial.release;

      services.tmate-ssh-server = {
        enable = true;
        openFirewall = true;
        port = port;
        host = "10.10.50.1"; # The wireguard IP, only to show the correct links.
        advertisedPort = port;
      };
    };
  };

  # Port-forward inbound 22222 -> container, WITHOUT masquerade.
  # This is only destination NAT (DNAT), the container cannot reach the internet.
  networking.nat = {
    enable = true;
    externalInterface = "wg0";

    # Destination NAT
    forwardPorts = [
      {
        sourcePort = port;
        proto = "tcp";
        destination = "10.0.0.2:${toString port}";
      }
    ];
  };
}
