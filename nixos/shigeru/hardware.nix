{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader = {
    grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
    efi = {
      efiSysMountPoint = "/efi";
      canTouchEfiVariables = true;
    };
  };
  boot.initrd.kernelModules = [ "nvme" ];

  fileSystems."/efi" = { device = "/dev/disk/by-uuid/6A41-3ED8"; fsType = "vfat"; };
  fileSystems."/" = { device = "/dev/disk/by-uuid/25c29fa5-df2a-437f-a05d-c1c3b61a8729"; fsType = "ext4"; };
}
