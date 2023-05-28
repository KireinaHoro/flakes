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
        };
        kernelPatches = (builtins.map (patch: { inherit patch; }) [
          ./patches/0000-Disable-CLOCK_ALLOW_WRITE_DEBUGFS.patch
          ./patches/0001-fix-rockchip-iomux-init-include.patch
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

    initrd.availableKernelModules = lib.mkForce [ "ext4" "mmc_block" ];
    initrd.kernelModules = [];

    extraModulePackages = [];
  };

  system.stateVersion = lib.traceSeq config.boot.initrd.availableKernelModules "23.05";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_ROOTFS";
      fsType = "ext4";
    };
    "/data" = {
      device = "/dev/disk/by-label/iori-data";
      fsType = "xfs";
    };
    "/tmp" = {
      device = "/data/tmp";
      options = [ "bind" ];
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
