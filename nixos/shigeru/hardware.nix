{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/boot" = { device = "/dev/disk/by-uuid/6A41-3ED8"; fsType = "vfat"; };
  fileSystems."/" = { device = "/dev/disk/by-uuid/25c29fa5-df2a-437f-a05d-c1c3b61a8729"; fsType = "ext4"; };
  swapDevices = [ { device = "/dev/disk/by-uuid/00fb9e9a-5251-431f-8b8e-9b2bdcb8e5e5"; } ];
}
