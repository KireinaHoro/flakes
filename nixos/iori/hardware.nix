{ config, lib, pkgs, modulesPath, ... }:

{
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.initrd.availableKernelModules = lib.mkForce [ "usbhid" "md_mod" "raid0" "raid1" "raid10" "raid456" "ext2" "ext4" "sd_mod" "sr_mod" "mmc_block" "uhci_hcd" "ehci_hcd" "ehci_pci" "ohci_hcd" "ohci_pci" "xhci_hcd" "xhci_pci" "usbhid" "hid_generic" "hid_lenovo" "hid_apple" "hid_roccat" "hid_logitech_hidpp" "hid_logitech_dj" "hid_microsoft" "hid_cherry" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  system.stateVersion = lib.traceSeq config.boot.initrd.availableKernelModules "23.05";

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_ROOTFS";
      fsType = "ext4";
    };
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
