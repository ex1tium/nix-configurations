#!/usr/bin/env bash
# Safe wrapper for install-elara.sh that handles download and execution properly
# This avoids issues with piping curl directly to bash

set -euo pipefail

echo "🚀 NixOS Installer for Elara"
echo "=============================="

# Check if we're on NixOS
if [[ ! -f /etc/NIXOS ]]; then
  echo "❌ This script must be run from a NixOS environment"
  echo "   Please boot from a NixOS ISO first"
  exit 1
fi

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo "❌ Do NOT run as root - use a normal user with sudo access"
  exit 1
fi

# Download the installer script
REPO_URL="https://raw.githubusercontent.com/ex1tium/nix-configurations/main/scripts/install-elara.sh"
TEMP_SCRIPT=$(mktemp)

echo "📥 Downloading installer script..."
if command -v curl >/dev/null; then
  curl -fsSL "$REPO_URL" -o "$TEMP_SCRIPT"
elif command -v wget >/dev/null; then
  wget -q "$REPO_URL" -O "$TEMP_SCRIPT"
else
  echo "❌ Neither curl nor wget available"
  exit 1
fi

# Verify download
if [[ ! -s "$TEMP_SCRIPT" ]]; then
  echo "❌ Failed to download installer script"
  exit 1
fi

# Make executable and run
chmod +x "$TEMP_SCRIPT"
echo "🔧 Running installer..."
exec bash "$TEMP_SCRIPT" "$@"
