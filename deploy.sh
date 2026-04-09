#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

echo ">>> Starting Themearr Deployment..."

# 1. Ensure git is installed
apt-get update -qq
apt-get install -y git -qq

# 2. Prepare the installation directory
INSTALL_DIR="/opt/themearr"
if [ -d "$INSTALL_DIR" ]; then
    echo ">>> Cleaning up existing installation..."
    rm -rf "$INSTALL_DIR"
fi

# 3. Clone the repository directly from your GitHub
echo ">>> Cloning repository..."
# REPLACE THE URL BELOW WITH YOUR ACTUAL GITHUB REPO URL
git clone https://github.com/Actuallbug2005/themearr.git "$INSTALL_DIR"

# 4. Execute the native installation script
echo ">>> Executing native installer..."
cd "$INSTALL_DIR"
chmod +x install.sh
bash install.sh

echo ">>> Deployment Complete!"
echo ">>> Action Required: Configure /opt/themearr/.env with your Radarr credentials."
echo ">>> Then run: systemctl restart themearr"
