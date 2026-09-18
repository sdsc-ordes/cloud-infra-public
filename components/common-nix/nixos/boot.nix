{ modulesPath, lib, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  boot = {
    growPartition = true;

    loader.grub = {
      # No need to set devices,
      # disko will add all devices that have a EF02 partition to the list already
      # devices = [ ];

      efiSupport = true;
      efiInstallAsRemovable = true;

      # Restrict the number of boot entries to prevent full /boot partition.
      configurationLimit = lib.mkDefault 5;
    };

    initrd = {
      availableKernelModules = [
        "ata_piix"
        "uhci_hcd"

        "virtio"
        "virtio_net"
        "virtio_pci"
        "virtio_blk"

        # NVME
        "nvme"
        # For VM where disks present virtio-scsi.
        "sd_mod"
      ];

      kernelModules = [ "" ];
    };

    kernelModules = [
      "kvm-intel"
      "kvm-amd"
    ];

    extraModulePackages = [ ];
  };
}
