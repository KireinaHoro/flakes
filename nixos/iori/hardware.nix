{ config, lib, pkgs, modulesPath, ... }:

{
  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    kernelPackages = pkgs.linuxPackages_latest;
    kernelModules = [];
    kernelParams = lib.mkAfter [
      "console=ttyFIQ0,115200n8"
      "console=ttyS2,115200n8"
      "earlycon=uart8250,mmio32,0xfeb50000"
    ];

    supportedFilesystems = [ "ext4" "xfs" ];

    initrd.availableKernelModules = lib.mkForce [
      # root is on MMC, ext4
      "ext4" "mmc_block"
      # /nix/store is on NVMe SSD over PCIe, xfs
      "phy-rockchip-naneng-combphy" "pinctrl-rk805"
      "xfs" "nvme"
    ];

    initrd.systemd = {
      enable = true;
      emergencyAccess = true;
      # to inspect PCIe devices in emergency shell
      initrdBin = [ pkgs.pciutils ];
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
