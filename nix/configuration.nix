{ config, pkgs, lib, ... }:
{
  imports = [
    # Config VM-spécifique injectée par Terraform/cloud-init au déploiement
    ./machine.nix
  ];

  # ============================================================
  # Boot / initrd
  # ============================================================
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_scsi"  # disques VirtIO (Proxmox/KVM)
    "ahci" "sd_mod" "sr_mod"                  # SATA / générique
  ];

  # ============================================================
  # Système
  # ============================================================
  system.stateVersion = "25.11";
  # Hostname par défaut dans l'image — cloud-init l'écrase au 1er boot
  # et /var/lib/cloud-hostname le restaure aux boots suivants.
  networking.hostName = "nixos-template";
  networking.useDHCP = false; # cloud-init gère le DHCP par interface
  time.timeZone = "Europe/Paris";
  i18n.defaultLocale = "fr_FR.UTF-8";
  console.keyMap = "us";

  # ============================================================
  # Services de base
  # ============================================================
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  services.qemuGuest.enable = true;

  services.cloud-init = {
    enable = true;
    network.enable = true;
  };

  # ============================================================
  # Shell
  # ============================================================
  programs.fish.enable = true;

  # ============================================================
  # Sudo : NOPASSWD pour le groupe wheel
  # ============================================================
  security.sudo.wheelNeedsPassword = false;

  # ============================================================
  # Fichiers /etc gérés déclarativement
  # ============================================================
  environment.etc = {
    # ---- Skeleton appliqué à chaque user créé par cloud-init ----
    "skel/.config/fish/config.fish".text = ''
      if status is-interactive
        set -gx EDITOR vim
        alias k=kubectl
        alias ll='ls -lah'
        alias g=git
      end
    '';

    "skel/.config/fish/functions/fish_prompt.fish".text = ''
      function fish_prompt
        set_color cyan;   echo -n (whoami)
        set_color normal; echo -n '@'
        set_color yellow; echo -n (hostname)
        set_color normal; echo -n ':'
        set_color green;  echo -n (prompt_pwd)
        set_color normal; echo -n '> '
      end
    '';

    "skel/.vimrc".text = ''
      set number
      set tabstop=2
      set shiftwidth=2
      set expandtab
      syntax on
    '';

    "skel/.gitconfig".text = ''
      [init]
        defaultBranch = main
      [pull]
        rebase = false
    '';

    # ---- Configuration cloud-init : user par défaut ----
    # Le user créé par `qm set --ciuser <name>` héritera de :
    #   - groupe wheel  (donc sudo NOPASSWD via wheelNeedsPassword=false)
    #   - shell fish
    #   - règle sudoers explicite (ceinture + bretelles)
    "cloud/cloud.cfg.d/99-nixos-user.cfg".text = ''
      system_info:
        default_user:
          groups: [wheel]
          sudo: ["ALL=(ALL) NOPASSWD:ALL"]
          shell: /run/current-system/sw/bin/fish
    '';
  };

  # ============================================================
  # Hostname persisté par cloud-init
  # ============================================================
  # NixOS réapplique networking.hostName à chaque boot.
  # Ce service lit le hostname écrit par cloud-init dans /var/lib/cloud-hostname
  # et le restaure après l'activation NixOS.
  systemd.services.cloud-hostname-restore = {
    description = "Restore hostname written by cloud-init";
    after = [ "systemd-hostnamed.service" "cloud-config.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = let
        script = pkgs.writeShellScript "cloud-hostname-restore" ''
          if [ -f /var/lib/cloud-hostname ]; then
            hostname "$(cat /var/lib/cloud-hostname)"
          fi
        '';
      in "${script}";
    };
  };

  # ============================================================
  # Nettoyage cloud-init avant création du template
  # ============================================================
  # Crée /var/lib/cloud/clean-on-shutdown pour déclencher le nettoyage.
  # Le Makefile (make prepare-template) s'en charge automatiquement.
  systemd.services.cloud-init-clean = {
    description = "Clean cloud-init state before template creation";
    wantedBy = [ "shutdown.target" "halt.target" "poweroff.target" "reboot.target" ];
    before = [ "shutdown.target" "halt.target" "poweroff.target" "reboot.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      ExecStart = let
        script = pkgs.writeShellScript "cloud-init-clean" ''
          if [ -f /var/lib/cloud/clean-on-shutdown ]; then
            echo "Cleaning cloud-init state for template creation..."
            cloud-init clean --logs
            rm -f /var/lib/cloud/clean-on-shutdown
            rm -f /var/lib/cloud-hostname
            # Vider le machine-id pour que chaque clone en génère un unique au boot
            > /etc/machine-id
          fi
        '';
      in "${script}";
    };
  };

  # ============================================================
  # Packages système
  # ============================================================
  environment.systemPackages = with pkgs; [
    vim
    fish
    git
    curl
    wget
    htop
    busybox
  ];

  # ============================================================
  # Nix
  # ============================================================
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Permet à nixos-rebuild switch de fonctionner dans la VM sans accès internet
  # en utilisant le nixpkgs déjà présent dans le store (buildé avec l'image).
  nix.nixPath = [ "nixpkgs=${pkgs.path}" ];
  nix.registry.nixpkgs.to = {
    type = "path";
    path = "${pkgs.path}";
  };
}
