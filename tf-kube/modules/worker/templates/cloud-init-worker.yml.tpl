#cloud-config

hostname: ${vm_hostname}
preserve_hostname: false
timezone: ${timezone}

write_files:
  - path: /var/lib/cloud-hostname
    content: "${vm_hostname}\n"
    permissions: '0644'


  - path: /root/k8s-join.sh
    permissions: '0755'
    content: |
      #!/run/current-system/sw/bin/bash
      set -euo pipefail

      export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH

      MASTER_IP=${master_ip}
      JOIN_URL="http://$MASTER_IP:9999/kubeadm-join.sh"

      # ---- Appliquer le hostname avant kubeadm join ----
      hostname "$(cat /var/lib/cloud-hostname)"

      # ---- Attendre que containerd soit prêt ----
      systemctl is-active --wait containerd

      # ---- Récupérer le join-command depuis le master ----
      # Retry toutes les 15s pendant 10 minutes max.
      JOIN_CMD=""
      for i in $(seq 1 40); do
        JOIN_CMD=$(curl -sf --max-time 5 "$JOIN_URL") && break
        echo "[worker] Tentative $i/40 — master pas encore prêt, attente 15s..."
        sleep 15
      done

      if [ -z "$JOIN_CMD" ]; then
        echo "[worker] ERREUR : impossible de récupérer le join-command depuis $MASTER_IP" >&2
        exit 1
      fi

      echo "$JOIN_CMD" > /root/kubeadm-join.sh
      chmod 600 /root/kubeadm-join.sh

      # ---- Rejoindre le cluster ----
      bash /root/kubeadm-join.sh 2>&1 | tee /root/kubeadm-join.log

runcmd:
  - /root/k8s-join.sh 2>&1 | tee /root/k8s-join-bootstrap.log

final_message: |
  =====================================================
  NixOS kubeadm worker ready — boot took $UPTIME seconds
  Bootstrap log : /root/k8s-join-bootstrap.log
  Log join      : /root/kubeadm-join.log
  =====================================================
