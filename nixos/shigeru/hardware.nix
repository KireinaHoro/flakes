{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/boot" = { device = "/dev/disk/by-uuid/5D86-06F8"; fsType = "vfat"; };
  fileSystems."/" = { device = "/dev/disk/by-uuid/25c29fa5-df2a-437f-a05d-c1c3b61a8729"; fsType = "ext4"; };
}
