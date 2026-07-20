# Déclare les filesystems et le bootloader attendus par make-disk-image.nix
# (labels "nixos" / "ESP") — nécessaire à la fois pour builder le qcow2 via
# flake.nix et pour que `nixos-rebuild switch` classique fonctionne une fois
# à l'intérieur de la VM (sinon : assertions fileSystems."/" et bootloader
# manquantes, car flake.nix n'est jamais copié sur la VM).
{ ... }:
{
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };
  fileSystems."/boot" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
  };
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
}
