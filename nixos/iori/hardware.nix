{ config, lib, pkgs, modulesPath, ... }:

{
  boot = {
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;

    kernelPackages = with pkgs; lib.mkForce (linuxPackagesFor (
      linux-rock5b.override { argsOverride = {
        structuredExtraConfig = with lib.kernel; {
          XHCI_HCD = module;
          XHCI_HCD_PLATFORM = module;
          OHCI_HCD = module;
          OHCI_HCD_PLATFORM = module;
          EHCI_HCD = module;
          EHCI_HCD_PLATFORM = module;
          DRM_ROCKCHIP = no;
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
        }; }; }));
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
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
