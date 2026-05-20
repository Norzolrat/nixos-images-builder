{
  description = "NixOS base VM image for Proxmox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs   = nixpkgs.legacyPackages.${system};

    # Module requis par make-disk-image.nix : déclare les FS et le bootloader.
    # Les labels (nixos / ESP) correspondent à ce que make-disk-image crée.
    diskImageModule = {
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
    };

    makeQcow2 = modules:
      let cfg = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = modules ++ [ diskImageModule ];
      };
      in import "${nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs;
        lib    = nixpkgs.lib;
        config = cfg.config;
        format             = "qcow2";
        diskSize           = "auto";
        partitionTableType = "efi";
      };

    modules-base        = [ ./configuration.nix ];
    modules-k8s         = [ ./configuration.nix ./k8s.nix ];
    modules-gpu-amd     = [ ./configuration.nix ./gpu-amd.nix ];
    modules-k8s-gpu-amd = [ ./configuration.nix ./k8s.nix ./gpu-amd.nix ];
  in {
    # nixosConfigurations : sans diskImageModule (pour nixos-rebuild, etc.)
    nixosConfigurations = {
      nixos-base        = nixpkgs.lib.nixosSystem { inherit system; modules = modules-base; };
      nixos-k8s         = nixpkgs.lib.nixosSystem { inherit system; modules = modules-k8s; };
      nixos-gpu-amd     = nixpkgs.lib.nixosSystem { inherit system; modules = modules-gpu-amd; };
      nixos-k8s-gpu-amd = nixpkgs.lib.nixosSystem { inherit system; modules = modules-k8s-gpu-amd; };
    };

    packages.${system} = {
      nixos-base        = makeQcow2 modules-base;
      nixos-k8s         = makeQcow2 modules-k8s;
      nixos-gpu-amd     = makeQcow2 modules-gpu-amd;
      nixos-k8s-gpu-amd = makeQcow2 modules-k8s-gpu-amd;
    };
  };
}
