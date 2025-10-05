{ config, lib, pkgs, modulesPath, ... }:

{
  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    kernelPackages = pkgs.linuxKernel.packages.linux_6_16;
    kernelModules = [];
    kernelParams = lib.mkAfter [
      "console=ttyFIQ0,115200n8"
      "console=ttyS2,115200n8"
      "earlycon=uart8250,mmio32,0xfeb50000"
      "earlyprintk"
    ];

    initrd.availableKernelModules = lib.mkForce [ "ext4" "xfs" "nvme" "mmc_block" ];
    initrd.kernelModules = [ "phy_rockchip_naneng_combphy" "fusb302" "tcpm" "rk805_pwrkey" ];

    supportedFilesystems = [ "ext4" "xfs" ];
    extraModulePackages = [];
    initrd.systemd = {
      enable = true;
      emergencyAccess = true;
    };
  };

  system.stateVersion = "23.05";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_ROOTFS";
      fsType = "ext4";
    };
    "/data" = {
      device = "/dev/disk/by-label/iori-data";
      fsType = "xfs";
      options = [ "nofail" "x-systemd.device-timeout=5s" ];
      neededForBoot = true;
    };
    "/tmp" = {
      device = "/data/tmp";
      options = [ "bind" ];
      depends = [ "/data" ];
    };
    "/nix/store" = {
      device = "/data/nix-store";
      options = [ "bind" "ro" "noatime" "discard" ];
      depends = [ "/data" ];
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
  hardware.enableRedistributableFirmware = true;
}
