#cloud-config

hostname: ${vm_hostname}
preserve_hostname: false
timezone: ${timezone}

write_files:
  - path: /var/lib/cloud-hostname
    content: "${vm_hostname}\n"
    permissions: '0644'

runcmd:
  - hostname $(cat /var/lib/cloud-hostname)
  - hostnamectl set-hostname $(cat /var/lib/cloud-hostname)

final_message: |
  =====================================================
  NixOS base VM ready — boot took $UPTIME seconds
  SSH : ssh ${manager_user}@${vm_hostname}
  =====================================================
