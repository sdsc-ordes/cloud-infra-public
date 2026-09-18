{
  lib,
  ...
}:
let
  port = 22223;
in
{
  containers.upterm = {
    autoStart = true;

    # Create a VETH pair
    privateNetwork = true;
    hostAddress = "10.0.1.1";
    localAddress = "10.0.1.2";

    config = {
      system.stateVersion = lib.trivial.release;

      services.uptermd = {
        enable = true;
        openFirewall = true;
        port = port;
      };
    };
  };

  # Port-forward inbound 22223 -> container, WITHOUT masquerade.
  # This is only destination NAT (DNAT), the container cannot reach the internet.
  networking.nat = {
    enable = true;
    externalInterface = "wg0";

    # Destination NAT
    forwardPorts = [
      {
        sourcePort = port;
        proto = "tcp";
        destination = "10.0.1.2:${toString port}";
      }
    ];
  };
}
