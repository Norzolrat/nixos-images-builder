{ config, pkgs, lib, ... }:
{
  # ============================================================
  # Prérequis kernel
  # ============================================================
  boot.kernelModules = [
    "br_netfilter" "overlay"
    "ip_vs" "ip_vs_rr" "ip_vs_wrr" "ip_vs_sh"
    "wireguard"
  ];

  boot.kernel.sysctl = {
    "net.bridge.bridge-nf-call-iptables"  = 1;
    "net.bridge.bridge-nf-call-ip6tables" = 1;
    "net.ipv4.ip_forward"                 = 1;
    "fs.inotify.max_user_instances"       = 8192;
    "fs.inotify.max_user_watches"         = 524288;
  };

  swapDevices = lib.mkForce [ ];
  zramSwap.enable = false;

  # ============================================================
  # Container runtime
  # ============================================================
  virtualisation.containerd = {
    enable = true;
    settings = {
      plugins."io.containerd.grpc.v1.cri" = {
        sandbox_image = "registry.k8s.io/pause:3.10.1";
        containerd.runtimes.runc.options.SystemdCgroup = true;
        cni = {
          bin_dir = "/opt/cni/bin";
          conf_dir = "/etc/cni/net.d";
        };
      };
    };
  };

  environment.etc."crictl.yaml".text = ''
    runtime-endpoint: unix:///run/containerd/containerd.sock
    image-endpoint: unix:///run/containerd/containerd.sock
    timeout: 10
  '';

  # ============================================================
  # Packages
  # ============================================================
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes
    cri-tools
    cni-plugins
    kubernetes-helm
    ethtool socat conntrack-tools ipset iptables iproute2
  ];

  # ============================================================
  # FHS paths attendus par kubeadm
  # ============================================================
  systemd.tmpfiles.rules = [
    "d /opt/cni 0755 root root - -"
    "d /opt/cni/bin 0755 root root - -"
    "L+ /usr/bin/kubelet - - - - /run/current-system/sw/bin/kubelet"
  ];

  # /opt/cni/bin must be a real writable directory so Cilium can place its
  # own helper binaries (cilium-mount, cilium-sysctlfix) alongside the CNI plugins.
  # A Nix-store symlink is read-only and causes Cilium's init containers to fail.
  systemd.services.cni-plugins-install = {
    description = "Copy CNI plugins to writable /opt/cni/bin";
    wantedBy = [ "multi-user.target" ];
    before = [ "kubelet.service" "containerd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'cp -n ${pkgs.cni-plugins}/bin/* /opt/cni/bin/'";
    };
  };

  # ============================================================
  # Firewall
  # ============================================================
  networking.firewall = {
    enable = true;
    # "loose" : accepte les paquets inter-VLAN arrivant sur eth1 (DMZ) même si
    # la route retour passe par eth0 — nécessaire pour que 10.0.1.200 soit
    # joignable depuis vlan_mgmt et internet (le service dmz-policy-routing
    # assure ensuite que les réponses repartent bien par eth1).
    checkReversePath = "loose";
    allowedTCPPorts = [ 22 6443 2379 2380 10250 10257 10259 30000 179 5473 9999
      # Traefik — accessible via eth0 (cible NAT SNS) et eth1 (VLAN dmz)
      80 443 8080
      # Teleport — TCP passthrough bastion
      3023 3024 3026
    ];
    allowedUDPPorts = [ 4789 ];
  };

  # ============================================================
  # kubelet : unité systemd
  # Le drop-in de kubeadm ne peut pas être écrit dans
  # /etc/systemd/system/ sur NixOS (read-only depuis le store).
  # On hard-code donc les flags que kubeadm y mettrait normalement.
  # ============================================================
  services.kubernetes.kubelet.enable = lib.mkForce false;

  systemd.services.kubelet = {
    description = "kubelet: The Kubernetes Node Agent";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" "containerd.service" ];
    startLimitIntervalSec = 0;

    path = with pkgs; [
      kubernetes cri-tools
      iptables iproute2 ethtool socat
      util-linux conntrack-tools mount ipset
    ];

    serviceConfig = {
      # kubeadm écrit ses flags dans kubeadm-flags.env au moment du init
      EnvironmentFile = "-/var/lib/kubelet/kubeadm-flags.env";

      # Flags hardcodés car le drop-in kubeadm ne peut pas être créé sur NixOS.
      # kubelet va crasher en boucle jusqu'à ce que kubeadm ait écrit
      # /var/lib/kubelet/config.yaml — c'est normal, Restart=always gère ça.
      ExecStart = lib.concatStringsSep " " [
        "/run/current-system/sw/bin/kubelet"
        "--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf"
        "--kubeconfig=/etc/kubernetes/kubelet.conf"
        "--config=/var/lib/kubelet/config.yaml"
        "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
        "$KUBELET_KUBEADM_ARGS"
      ];

      Restart = "always";
      RestartSec = 10;
    };
    # Pas de wantedBy : kubeadm démarre/arrête kubelet lui-même lors du init
  };

  # ============================================================
  # Policy routing eth1 (VLAN dmz) — retour symétrique
  # Sans ça, les réponses à des clients inter-VLAN (vlan_mgmt,
  # internet via SNS) partiraient par eth0 avec la mauvaise IP
  # source, cassant le handshake TCP vers 10.0.1.200.
  # ============================================================
  systemd.services.vlan-policy-routing = {
    description = "Policy routing VLAN NICs (eth1…) — symmetric return path";
    after    = [ "network-online.target" ];
    wants    = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    path     = with pkgs; [ iproute2 gawk ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "vlan-policy-routing" ''
        set -eu

        # Appliquer le policy routing sur chaque VLAN NIC (eth1…eth9)
        # Table N+200 pour ethN (eth1→201, eth2→202, …)
        for ETH in eth1 eth2 eth3 eth4 eth5 eth6 eth7 eth8 eth9; do
          ip link show "$ETH" >/dev/null 2>&1 || continue

          IP=$(ip -4 addr show dev "$ETH" 2>/dev/null \
               | awk '/inet /{split($2,a,"/"); print a[1]; exit}')
          [ -z "$IP" ] && continue

          IDX=$(echo "$ETH" | tr -d 'eth')
          TABLE=$((IDX + 200))

          GW=$(ip route show dev "$ETH" | awk '/default/{print $3; exit}')
          [ -z "$GW" ] && GW=$(echo "$IP" | awk -F. '{print $1"."$2"."$3".1"}')

          SUBNET=$(ip -4 addr show dev "$ETH" | awk '/inet /{print $2; exit}')

          ip route replace "$SUBNET" dev "$ETH"          table "$TABLE"
          ip route replace default   via "$GW" dev "$ETH" table "$TABLE"
          ip rule  add    from "$IP/32" table "$TABLE" priority "$TABLE" 2>/dev/null || true

          echo "vlan-policy-routing: $ETH — $IP via $GW (table $TABLE)"
        done
      '';
    };
  };
}