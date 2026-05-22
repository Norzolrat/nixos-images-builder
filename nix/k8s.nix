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
    allowedTCPPorts = [ 22 6443 2379 2380 10250 10257 10259 30000 179 5473 9999 ];
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
}