{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "virtio_pci" "sr_mod" "virtio_blk" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/e12f09f7-70f6-48cf-91b7-a9a22e40504b";
      fsType = "xfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/AA51-4760";
      fsType = "vfat";
      options = [ "fmask=0022" "dmask=0022" ];
    };
}
