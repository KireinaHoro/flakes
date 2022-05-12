{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    device = "nodev";
  };
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/boot/efi" = { device = "/dev/disk/by-uuid/0709-1E32"; fsType = "vfat"; };
  fileSystems."/boot" = { device = "/dev/sda2"; fsType = "ext4"; };
  fileSystems."/" = { device = "/dev/sda1"; fsType = "ext4"; };
}
