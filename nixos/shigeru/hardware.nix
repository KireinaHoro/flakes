{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.loader = {
    grub = {
      efiSupport = true;
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

  swapDevices = [ { device = "/dev/disk/by-uuid/068dda56-7795-46ef-b21a-0c18037c8acb"; } ];
}
