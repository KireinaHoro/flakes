{ config, lib, pkgs, modulesPath, ... }:

{
  # Oracle Cloud image: UEFI, root on /dev/disk/by-label/nixos (grown to the
  # boot volume size on first boot), ESP on by-label/ESP.
  #   qcow2 (custom image import): .#nixosConfigurations.nagisa.config.system.build.OCIImage
  #   raw.zst (dd onto an existing boot volume): .#nixosConfigurations.nagisa.config.system.build.OCIRawImage
  imports = [ (modulesPath + "/virtualisation/oci-image.nix") ];

  boot.initrd.kernelModules = [ "nvme" ];

  # No custom-image quota on the free tier: attach a clone of a boot volume to
  # a running VM as a block volume, write the image onto it, then swap it in
  # as the boot volume:
  #   ssh ubuntu@<ip> 'zstd -dc | sudo dd of=/dev/<clone> bs=4M conv=fsync status=progress' \
  #     < result/nagisa.raw.zst
  system.build.OCIRawImage = pkgs.runCommand "${config.networking.hostName}-raw-image" {
    nativeBuildInputs = [ pkgs.qemu-utils pkgs.zstd ];
  } ''
    mkdir $out
    qemu-img convert -O raw ${config.system.build.OCIImage}/*.qcow2 disk.raw
    zstd -q -T0 -10 disk.raw -o $out/${config.networking.hostName}.raw.zst
  '';
}
