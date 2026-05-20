{ config, pkgs, lib, ... }:
{
  # Pilote AMD
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules        = [ "amdgpu" ];

  # Firmware (obligatoire pour Navi 48 / RDNA 4)
  hardware.enableRedistributableFirmware = true;

  # Stack graphique + OpenCL
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      rocmPackages.clr.icd
    ];
  };

  # Accès GPU sans root
  users.groups.render = {};
  users.groups.video  = {};
  services.udev.extraRules = ''
    SUBSYSTEM=="kfd",  GROUP="render", MODE="0660"
    SUBSYSTEM=="drm",  KERNEL=="renderD*", GROUP="render", MODE="0660"
  '';

  # User cloud-init dans les bons groupes
  environment.etc."cloud/cloud.cfg.d/99z-nixos-gpu-user.cfg".text = ''
    system_info:
      default_user:
        groups: [wheel, render, video]
        sudo: ["ALL=(ALL) NOPASSWD:ALL"]
        shell: /run/current-system/sw/bin/fish
  '';

  # Python + ROCm pour tester la carte
  environment.systemPackages = with pkgs; [
    python3
    rocmPackages.rocm-smi    # rocm-smi : voir si la carte est détectée
    rocmPackages.rocminfo    # rocminfo : vérifier l'arch gfx
  ];
}
