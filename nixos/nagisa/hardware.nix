{ config, lib, pkgs, modulesPath, ... }:

{
  # Oracle Cloud image: UEFI, root on /dev/disk/by-label/nixos (grown to the
  # boot volume size on first boot), ESP on by-label/ESP.
  #   qcow2 (custom image import): .#nixosConfigurations.nagisa.config.system.build.OCIImage
  #   raw.zst (dd onto an existing boot volume): .#nixosConfigurations.nagisa.config.system.build.OCIRawImage
  imports = [ (modulesPath + "/virtualisation/oci-image.nix") ];

  boot.initrd.kernelModules = [ "nvme" ];

  # The OCI module ends with console=ttyAMA0 (aarch64), which doesn't exist on
  # x86 and leaves tty1 as /dev/console.  Repeating ttyS0 last makes it the
  # preferred console, so stage-1 and systemd status also go to the OCI serial
  # console connection (kernel messages go to tty1 as well either way).
  boot.kernelParams = lib.mkAfter [ "console=ttyS0,115200" ];

  fileSystems."/srv/shared" = {
    device = "/dev/disk/by-uuid/b40044f5-e119-4187-8d6d-f697278298aa";
    fsType = "ext4";
    options = [ "nofail" "noexec" ];
  };

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
