#!/bin/bash

# Mojar Player Pro Installer Script
echo "Installing Mojar Player Pro v1.0.7..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

# Install dependencies
echo "Installing dependencies..."
apt-get update
apt-get install -y libgtk-3-0 libmpv2 libgstreamer-plugins-base1.0-0

# Install Mojar Player Pro
echo "Installing Mojar Player Pro..."
dpkg -i build/mojar-player-pro_1.0.7_amd64.deb
apt-get install -f -y

echo "Installation complete!"
echo "You can now launch Mojar Player Pro from your applications menu or by running 'mojar_player_pro' in terminal." 