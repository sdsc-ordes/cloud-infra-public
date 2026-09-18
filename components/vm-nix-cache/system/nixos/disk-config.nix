# Standard disk setup:
# Taken from: https://raw.githubusercontent.com/nix-community/nixos-anywhere-examples/refs/heads/main/disk-config.nix
{ inputs, lib, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
  ];

  disko.devices = {
    disk.disk1 = {
      device = lib.mkDefault "/dev/sda";
      type = "disk";

      content = {
        type = "gpt";
        partitions = {
          boot = {
            name = "boot";
            size = "1M";
            type = "EF02";
          };
          esp = {
            name = "ESP";
            size = "500M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          root = {
            name = "root";
            end = "-8G"; # Allocate remaining space for root, leaving 8GB for swap
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
          swap = {
            size = "100%";
            content = {
              type = "swap";
              discardPolicy = "both";
            };
          };
        };
      };
    };
  };
}
