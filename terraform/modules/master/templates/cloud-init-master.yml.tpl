#cloud-config

hostname: ${vm_hostname}
preserve_hostname: false
timezone: ${timezone}

write_files:
  - path: /var/lib/cloud-hostname
    content: "${vm_hostname}\n"
    permissions: '0644'

  # Fichiers NixOS sources — nécessaires pour que nixos-rebuild switch fonctionne sur la VM
  - path: /etc/nixos/configuration.nix
    permissions: '0644'
    encoding: b64
    content: ${configuration_nix_b64}

  - path: /etc/nixos/k8s.nix
    permissions: '0644'
    encoding: b64
    content: ${k8s_nix_b64}

  - path: /etc/nixos/gpu-amd.nix
    permissions: '0644'
    encoding: b64
    content: ${gpu_amd_nix_b64}

  - path: /etc/nixos/machine.nix
    permissions: '0644'
    encoding: b64
    content: ${machine_nix_b64}

  - path: /root/k8s-bootstrap.sh
    permissions: '0755'
    content: |
      #!/run/current-system/sw/bin/bash
      set -euo pipefail

      export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH

      NODE_IP=$(ip route get 1.1.1.1 | awk 'NR==1{print $7}')
      DEFAULT_USER=$(awk -F: '$3==1000{print $1}' /etc/passwd)
      HOME_DIR="/home/$DEFAULT_USER"

      # ---- Appliquer le hostname avant kubeadm init ----
      hostname "$(cat /var/lib/cloud-hostname)"

      # ---- Attendre que containerd soit prêt ----
      systemctl is-active --wait containerd

      # ---- kubeadm init ----
      kubeadm init \
        --pod-network-cidr=${pod_network_cidr} \
        --service-cidr=10.96.0.0/12 \
        --apiserver-advertise-address=$NODE_IP \
        2>&1 | tee /root/kubeadm-init.log

      # ---- kubectl : config pour le user par défaut ----
      export KUBECONFIG=/etc/kubernetes/admin.conf

      mkdir -p "$HOME_DIR/.kube"
      cp /etc/kubernetes/admin.conf "$HOME_DIR/.kube/config"
      chown -R "$DEFAULT_USER:" "$HOME_DIR/.kube"

      cp /etc/kubernetes/admin.conf "$HOME_DIR/kubeconfig"
      chown "$DEFAULT_USER:" "$HOME_DIR/kubeconfig"
      chmod 600 "$HOME_DIR/kubeconfig"

      # ---- Calico : installer le CNI ----
      curl -fsSL "https://raw.githubusercontent.com/projectcalico/calico/v${calico_version}/manifests/calico.yaml" \
        -o /root/calico.yaml
      # Aligner le pod CIDR avec celui passé à kubeadm
      sed -i 's|192\.168\.0\.0/16|${pod_network_cidr}|g' /root/calico.yaml
      kubectl apply -f /root/calico.yaml 2>&1 | tee /root/calico-install.log

      # ---- Attendre que Calico soit ready ----
      kubectl rollout status daemonset/calico-node -n kube-system --timeout=10m

      # ---- Générer le join-command (récupéré par Terraform via SCP) ----
      kubeadm token create --print-join-command > /root/kubeadm-join.sh
      chmod 644 /root/kubeadm-join.sh

runcmd:
  # Régénérer le machine-id (figé dans l'image) pour que chaque VM soit unique
  - rm -f /etc/machine-id
  - systemd-machine-id-setup
  # Régénérer les clés SSH hôtes (évite les conflits known_hosts entre rebuilds)
  - rm -f /etc/ssh/ssh_host_*
  - ssh-keygen -A
  - systemctl restart sshd
  # Renommer les NICs par position (insensible aux noms prédictifs ens18/ens19)
  # On capture FIRST et SECOND avant tout rename pour éviter les courses
  - >-
    FIRST=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | head -1);
    SECOND=$(ip -o link show | awk -F': ' '{print $2}' | grep -v '^lo$' | sed -n '2p');
    [ -n "$FIRST"  ] && [ "$FIRST"  != "eth0" ] && ip link set "$FIRST"  name eth0 || true;
    [ -n "$SECOND" ] && [ "$SECOND" != "eth1" ] && ip link set "$SECOND" name eth1 || true
  - /run/current-system/sw/bin/nixos-rebuild switch -I nixos-config=/etc/nixos/configuration.nix 2>&1 | tee /root/nixos-rebuild.log || echo "[WARNING] nixos-rebuild switch échoué — check /root/nixos-rebuild.log"
  - sleep 3
  - /root/k8s-bootstrap.sh 2>&1 | tee /root/k8s-bootstrap.log

final_message: |
  =====================================================
  NixOS kubeadm master ready — boot took $UPTIME seconds
  Join command : cat /root/kubeadm-join.sh
  Kubeconfig   : scp ${vm_hostname}:~/kubeconfig ~/.kube/config
  Bootstrap log: /root/k8s-bootstrap.log
  NixOS rebuild: /root/nixos-rebuild.log
  =====================================================
