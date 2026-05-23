#cloud-config

hostname: ${vm_hostname}
preserve_hostname: false
timezone: ${timezone}

write_files:
  - path: /var/lib/cloud-hostname
    content: "${vm_hostname}\n"
    permissions: '0644'

# ---- Appliquer le hostname avant kubeadm join ----
runcmd:
  - hostname "$(cat /var/lib/cloud-hostname)"

final_message: |
  =====================================================
  NixOS kubeadm worker ready — boot took $UPTIME seconds
  Le join kubeadm est géré par Terraform (remote-exec)
  =====================================================
