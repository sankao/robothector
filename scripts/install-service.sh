#!/usr/bin/env bash
# Install the robothector systemd service on the Pi.
# Run from the project root: ssh robothector 'cd ~/robothector && bash scripts/install-service.sh'

set -euo pipefail

echo "Installing robothector.service..."

# Ensure gpio group membership
if ! groups | grep -q gpio; then
    echo "Adding user to gpio group..."
    sudo usermod -aG gpio "$USER"
    echo "NOTE: log out and back in for gpio group to take effect."
fi

sudo cp robothector.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable robothector
sudo systemctl restart robothector

echo "Done. Checking status..."
sleep 2
sudo systemctl status robothector --no-pager
