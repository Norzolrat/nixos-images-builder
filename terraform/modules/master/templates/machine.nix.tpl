# Généré par Terraform — NE PAS ÉDITER MANUELLEMENT
# VM : ${vm_hostname}
{ config, lib, pkgs, ... }:
{
  # k8s.nix + gpu-amd.nix : configuration.nix seul (via -I nixos-config=) ne les
  # importe jamais. Sans ça, "nixos-rebuild switch" sur la VM bascule vers une
  # config sans containerd/kubelet — l'image de base les avait via flake.nix,
  # mais un rebuild classique sur la VM ne relit pas flake.nix (jamais copié).
  imports = [ ./k8s.nix ./gpu-amd.nix ];

  networking.hostName = "${vm_hostname}";
  time.timeZone = "${timezone}";

  # Force le naming traditionnel (eth0, eth1, ...) dès le prochain boot
  boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];

  # Après nixos-rebuild, systemd-networkd gère le réseau complet.
  # cloud-init ne doit plus toucher aux interfaces (évite l'écrasement au prochain boot).
  services.cloud-init.network.enable = lib.mkForce false;

  # systemd-networkd : eth0 (mgmt statique) + eth1 trunk + subinterfaces VLAN
  systemd.network = {
    enable = true;

    networks = {
      # eth0 — management, IP statique injectée par Terraform
      "10-eth0" = {
        matchConfig.Name = "eth0";
        networkConfig = {
          Address = "${vm_ip}";
          Gateway = "${vm_gateway}";
          DNS     = "${vm_nameserver}";
          LinkLocalAddressing = "no";
        };
      };
%{ if length(vlan_subinterfaces) > 0 ~}

      # eth1 — trunk (parent des VLANs, pas d'IP directe)
      "20-eth1" = {
        matchConfig.Name = "eth1";
        networkConfig = {
          LinkLocalAddressing = "no";
          VLAN = [ ${join(" ", [for v in vlan_subinterfaces : "\"eth1.${v.vlan_id}\""])} ];
        };
      };
%{ for vlan in vlan_subinterfaces ~}

      "${vlan.file_prefix}-eth1-${vlan.vlan_id}" = {
        matchConfig.Name = "eth1.${vlan.vlan_id}";
        networkConfig.Address = "${vlan.ip}";
      };
%{ endfor ~}
%{ endif ~}
    };
%{ if length(vlan_subinterfaces) > 0 ~}

    netdevs = {
%{ for vlan in vlan_subinterfaces ~}
      "eth1-${vlan.vlan_id}" = {
        netdevConfig = { Name = "eth1.${vlan.vlan_id}"; Kind = "vlan"; };
        vlanConfig.Id = ${vlan.vlan_id};
      };
%{ endfor ~}
    };
%{ endif ~}
  };
}
