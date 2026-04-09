#!/usr/bin/env bash
set -euo pipefail

APP_DIR="/opt/themearr"
APP_USER="themearr"
APP_UID=1000
APP_GID=1000

# ── System dependencies ───────────────────────────────────────────────────────
echo "[1/5] Installing system packages…"
apt-get update -qq
apt-get install -y --no-install-recommends \
    python3-venv \
    python3-pip \
    ffmpeg \
    curl

# Install yt-dlp as a standalone binary (kept outside the venv so it can self-update)
echo "[2/5] Installing yt-dlp…"
curl -sSL https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp \
    -o /usr/local/bin/yt-dlp
chmod +x /usr/local/bin/yt-dlp

# ── System user & group ───────────────────────────────────────────────────────
echo "[3/5] Creating system user '${APP_USER}' (UID=${APP_UID}, GID=${APP_GID})…"

if ! getent group "${APP_USER}" > /dev/null 2>&1; then
    groupadd --gid "${APP_GID}" "${APP_USER}"
fi

if ! id -u "${APP_USER}" > /dev/null 2>&1; then
    useradd \
        --uid "${APP_UID}" \
        --gid "${APP_GID}" \
        --no-create-home \
        --shell /usr/sbin/nologin \
        --system \
        "${APP_USER}"
else
    # User exists — enforce the correct UID/GID
    usermod --uid "${APP_UID}" "${APP_USER}"
    groupmod --gid "${APP_GID}" "${APP_USER}"
fi

# ── App directory & Python venv ───────────────────────────────────────────────
echo "[4/5] Setting up application in ${APP_DIR}…"

mkdir -p "${APP_DIR}/data"

# Copy application source
cp -r app/         "${APP_DIR}/app"
cp    requirements.txt "${APP_DIR}/requirements.txt"

# Create .env from example if one doesn't exist yet
if [ ! -f "${APP_DIR}/.env" ]; then
    cp .env.example "${APP_DIR}/.env"
    echo "  → Created ${APP_DIR}/.env — edit it before starting the service."
fi

# Python virtual environment
python3 -m venv "${APP_DIR}/venv"
"${APP_DIR}/venv/bin/pip" install --quiet --upgrade pip
"${APP_DIR}/venv/bin/pip" install --quiet -r "${APP_DIR}/requirements.txt"

# Ownership
chown -R "${APP_USER}:${APP_USER}" "${APP_DIR}"

# ── systemd service ───────────────────────────────────────────────────────────
echo "[5/5] Installing systemd service…"
cp themearr.service /etc/systemd/system/themearr.service
systemctl daemon-reload
systemctl enable themearr.service

echo ""
echo "✔  Installation complete."
echo "   Edit ${APP_DIR}/.env, then run:  systemctl start themearr"
echo "   Logs:                            journalctl -u themearr -f"
