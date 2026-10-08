{ self }:
let
  boot = import ./boot.nix;
  home-manager = import ./home-manager.nix { inherit self; };
  keyboard = import ./keyboard.nix;
  networking = import ./networking.nix;
  nix = import ./nix.nix;
  packages = import ./packages.nix;
  services = import ./services.nix;
  settings = import ./settings.nix;
  secrets = import ./secrets.nix;
  server = import ./server.nix;
  system = import ./system.nix;
  time = import ./time.nix;
  user = import ./user.nix;
  virtualization = import ./virtualization.nix;
  vpn = import ./vpn.nix;
in
rec {
  inherit
    boot
    home-manager
    keyboard
    networking
    nix
    packages
    services
    settings
    server
    secrets
    system
    time
    user
    virtualization
    vpn
    ;

  all = minimal ++ [ virtualization ];

  minimal = [
    boot
    home-manager
    keyboard
    networking
    nix
    packages
    services
    settings
    secrets
    server
    system
    time
    user
    vpn
  ];
}
