#cloud-config

hostname: ${vm_hostname}
preserve_hostname: false
timezone: ${timezone}

write_files:
  - path: /var/lib/cloud-hostname
    content: "${vm_hostname}\n"
    permissions: '0644'

final_message: |
  =====================================================
  NixOS AMD GPU VM ready — boot took $UPTIME seconds
  SSH : ssh ${manager_user}@${vm_hostname}
  GPU : rocm-smi / rocminfo
  =====================================================
