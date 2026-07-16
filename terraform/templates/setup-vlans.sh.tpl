#!/run/current-system/sw/bin/bash
set -euo pipefail
export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH

MGMT_IFACE=$(ip route get 8.8.8.8 2>/dev/null | awk 'NR==1{print $5}')
TRUNK_IFACE=$(ip -o link show \
  | awk -F': ' '{gsub(/@.*/, "", $2); print $2}' \
  | grep -E '^(eth|ens|enp|eno)[0-9]' \
  | grep -v '\.' \
  | grep -v "^$MGMT_IFACE$" \
  | head -1)

[ -z "$TRUNK_IFACE" ] && { echo "[vlans] ERREUR: aucune interface trunk trouvee"; exit 1; }
echo "[vlans] Management=$MGMT_IFACE  Trunk=$TRUNK_IFACE"
ip link set $TRUNK_IFACE up

# ---- Sous-interfaces VLAN ----
%{ for vlan in vlans ~}
ip link add link $TRUNK_IFACE name $TRUNK_IFACE.${vlan.id} type vlan id ${vlan.id} 2>/dev/null || true
ip link set $TRUNK_IFACE.${vlan.id} up
ip addr add ${vlan.ip} dev $TRUNK_IFACE.${vlan.id} 2>/dev/null || true
%{ if vlan.gateway != null ~}
ip route add default via ${vlan.gateway} dev $TRUNK_IFACE.${vlan.id} metric $((200 + ${vlan.id})) 2>/dev/null || true
%{ endif ~}
echo "[vlans] VLAN ${vlan.id} -> ${vlan.ip} sur $TRUNK_IFACE.${vlan.id}"
%{ endfor ~}

# ---- Persistance NixOS ----
{
  printf '{ config, lib, pkgs, ... }:\n{\n  networking.vlans = {\n'
%{ for vlan in vlans ~}
  printf "    \"$TRUNK_IFACE.${vlan.id}\" = { id = ${vlan.id}; interface = \"$TRUNK_IFACE\"; };\n"
%{ endfor ~}
  printf '  };\n  networking.interfaces = {\n'
%{ for vlan in vlans ~}
  printf "    \"$TRUNK_IFACE.${vlan.id}\".ipv4.addresses = [{ address = \"${split("/", vlan.ip)[0]}\"; prefixLength = ${split("/", vlan.ip)[1]}; }];\n"
%{ endfor ~}
  printf '  };\n}\n'
} > /etc/nixos/vlans.nix

grep -q './vlans.nix' /etc/nixos/configuration.nix \
  || sed -i 's|imports = \[|imports = [\n    ./vlans.nix|' /etc/nixos/configuration.nix

nixos-rebuild switch 2>&1 | tee /root/vlans-rebuild.log \
  && echo "[vlans] nixos-rebuild OK — persistant" \
  || echo "[vlans] nixos-rebuild echoue — VLANs actifs via ip uniquement"
