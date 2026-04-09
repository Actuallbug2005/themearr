#!/usr/bin/env bash
set -e

# ── 1. Configuration ──────────────────────────────────────────────────────────
CTID=110                                      # Modify this if 110 is already taken
TEMPLATE="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst" 
HOST_MOVIE_MOUNT="/mnt/pve/nas_movies"
GITHUB_DEPLOY_URL="https://raw.githubusercontent.com/Actuallbug2005/themearr/main/deploy.sh"

echo "[1/5] Provisioning LXC ${CTID} on Proxmox 9..."

# ── 2. LXC Creation Subsystem ─────────────────────────────────────────────────
pct create $CTID $TEMPLATE \
  --arch amd64 \
  --ostype debian \
  --hostname themearr \
  --cores 2 \
  --memory 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage local-lvm \
  --unprivileged 1 \
  --features nesting=1

# ── 3. Storage & Namespace Mapping ────────────────────────────────────────────
echo "[2/5] Injecting Bind Mounts and UID/GID Maps..."

pct set $CTID -mp0 ${HOST_MOVIE_MOUNT},mp=/movies

# Inject UID 1000 mapping for SMB permission parity
cat <<EOF >> /etc/pve/lxc/$CTID.conf
lxc.idmap: u 0 100000 1000
lxc.idmap: g 0 100000 1000
lxc.idmap: u 1000 1000 1
lxc.idmap: g 1000 1000 1
lxc.idmap: u 1001 101001 64535
lxc.idmap: g 1001 101001 64535
EOF

# Authorise host root to pass subuids
usermod --add-subuids 1000-1000 root || true
usermod --add-subgids 1000-1000 root || true

# ── 4. Boot Sequence ──────────────────────────────────────────────────────────
echo "[3/5] Starting LXC ${CTID}..."
pct start $CTID

echo "[4/5] Waiting for network initialisation..."
sleep 10

# ── 5. Application Injection ──────────────────────────────────────────────────
echo "[5/5] Executing Application Installer inside LXC..."

pct exec $CTID -- bash -c "apt-get update -qq && apt-get install -y wget -qq"
pct exec $CTID -- bash -c "wget -qLO - ${GITHUB_DEPLOY_URL} | bash"

echo "─────────────────────────────────────────────────────────────────"
echo "✔ Deployment Complete."
echo "  Container IP:" $(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "  Action Required: Run 'pct exec $CTID -- nano /opt/themearr/.env' to set API keys."
echo "  Then run: 'pct exec $CTID -- systemctl restart themearr'"
echo "─────────────────────────────────────────────────────────────────"
