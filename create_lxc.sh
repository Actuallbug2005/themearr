#!/usr/bin/env bash
set -e

# ── 1. Dynamic Variables & UI Prompts ─────────────────────────────────────────
CTID=$(pvesh get /cluster/nextid)

# Prompt for Storage Pool
STORAGE=$(whiptail --title "Storage Pool" --inputbox "Enter the Proxmox storage pool for the LXC disk:" 10 58 "local-lvm" 3>&1 1>&2 2>&3)

# Prompt for Host Mount Path
HOST_MOVIE_MOUNT=$(whiptail --title "Host Movie Mount" --inputbox "Enter the absolute path to your SMB movie mount on this Proxmox host:" 10 58 "/mnt/pve/nas_movies" 3>&1 1>&2 2>&3)

GITHUB_DEPLOY_URL="https://raw.githubusercontent.com/Actuallbug2005/themearr/main/deploy.sh"

# ── 2. Dynamic Template Retrieval ─────────────────────────────────────────────
echo "[1/6] Fetching latest Debian 12 template index..."
pveam update >/dev/null

# Extract the exact filename of the latest debian-12-standard template
TEMPLATE_FILE=$(pveam available | grep -m 1 'debian-12-standard' | awk '{print $2}')

# Download it if it does not already exist on 'local' storage
if ! pveam list local | grep -q "$TEMPLATE_FILE"; then
    echo "      Template not found locally. Downloading $TEMPLATE_FILE..."
    pveam download local "$TEMPLATE_FILE" >/dev/null
fi
TEMPLATE="local:vztmpl/${TEMPLATE_FILE##*/}"

# ── 3. LXC Creation Subsystem ─────────────────────────────────────────────────
echo "[2/6] Provisioning LXC $CTID on $STORAGE..."
pct create $CTID $TEMPLATE \
  --arch amd64 \
  --ostype debian \
  --hostname themearr \
  --cores 2 \
  --memory 1024 \
  --net0 name=eth0,bridge=vmbr0,ip=dhcp \
  --storage "$STORAGE" \
  --unprivileged 1 \
  --features nesting=1

# ── 4. Storage & Namespace Mapping ────────────────────────────────────────────
echo "[3/6] Injecting Bind Mounts and UID/GID Maps..."

pct set $CTID -mp0 "$HOST_MOVIE_MOUNT",mp=/movies

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

# ── 5. Boot Sequence ──────────────────────────────────────────────────────────
echo "[4/6] Starting LXC $CTID..."
pct start $CTID

echo "[5/6] Waiting for network initialisation..."
sleep 10

# ── 6. Application Injection ──────────────────────────────────────────────────
echo "[6/6] Executing Application Installer inside LXC..."

pct exec $CTID -- bash -c "apt-get update -qq && apt-get install -y wget -qq"
pct exec $CTID -- bash -c "wget -qLO - ${GITHUB_DEPLOY_URL} | bash"

echo "─────────────────────────────────────────────────────────────────"
echo "✔ Deployment Complete."
echo "  Container ID: $CTID"
echo "  Container IP:" $(pct exec $CTID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo "  Action Required: Run 'pct exec $CTID -- nano /opt/themearr/.env' to set API keys."
echo "  Then run: 'pct exec $CTID -- systemctl restart themearr'"
echo "─────────────────────────────────────────────────────────────────"
