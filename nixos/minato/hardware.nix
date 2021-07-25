{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usb_storage" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/23303873-250c-44d0-b464-b0553f741720";
      fsType = "xfs";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/7843-4906";
      fsType = "vfat";
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/f456cfe8-6231-4efa-b137-71230a833677"; }
    ];

  hardware.cpu.intel.updateMicrocode = true;

  # disable checksum offloading for enp0s25
  systemd.services.ethtool = with pkgs; {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${ethtool}/bin/ethtool -K enp0s25 rx off tx off";
    };
    before = [ "network-pre.target" ];
    wants = [ "network-pre.target" ];
    wantedBy = [ "multi-user.target" ];
  };
}
