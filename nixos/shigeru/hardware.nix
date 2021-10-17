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
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
}
