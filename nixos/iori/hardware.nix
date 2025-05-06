{ config, lib, pkgs, modulesPath, ... }:

{
  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    kernelPackages = with pkgs; lib.mkForce (linuxPackagesFor (
      linux-rock5b.override { argsOverride = old: {
        structuredExtraConfig = with lib.kernel; old.structuredExtraConfig // {
          XHCI_HCD = module;
          XHCI_HCD_PLATFORM = module;
          OHCI_HCD = module;
          OHCI_HCD_PLATFORM = module;
          EHCI_HCD = module;
          EHCI_HCD_PLATFORM = module;
          DRM_ROCKCHIP = module;
          # broken dependency tracking in rockchip kernel
          TYPEC_DP_ALTMODE = module;
          ROCKCHIP_RKNPU = no;
          ROCKCHIP_VOP = no;
          ROCKCHIP_VOP2 = no;
          ROCKCHIP_MPP_RKVDEC = no;
          ROCKCHIP_MPP_RKVDEC2 = no;
          ROCKCHIP_MPP_RKVENC = no;
          ROCKCHIP_MPP_RKVENC2 = no;
          ROCKCHIP_MPP_VDPU1 = no;
          ROCKCHIP_MPP_VEPU1 = no;
          ROCKCHIP_MPP_VDPU2 = no;
          ROCKCHIP_MPP_VEPU2 = no;
          ROCKCHIP_MPP_IEP2 = no;
          ROCKCHIP_MPP_JPGDEC = no;
          ROCKCHIP_MPP_AV1DEC = no;
          NTFS_FS = module;
          GPIO_ROCKCHIP = module;
          VIDEO_ROCKCHIP_HDMIRX = no;
          # speed-up build
          DEBUG_INFO_BTF = lib.mkForce no;
        };
        ignoreConfigErrors = true;
        kernelPatches = (builtins.map (patch: { inherit patch; }) [
          ./patches/0002-disable-dp0.patch
        ]) ++ old.kernelPatches;
      }; }));
    kernelModules = [];
    kernelParams = lib.mkAfter [
      "console=ttyFIQ0,115200n8"
      "console=ttyS2,115200n8"
      "earlycon=uart8250,mmio32,0xfeb50000"
      "earlyprintk"
    ];

    initrd.availableKernelModules = lib.mkForce [ "ext4" "xfs" "nvme" "mmc_block" ];
    initrd.kernelModules = [ "gpio_rockchip" "rk806-spi" "rk806-core" "rk806-regulator" "pinctrl-rk806" ];

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
