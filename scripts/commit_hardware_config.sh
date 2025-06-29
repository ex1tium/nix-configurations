#!/usr/bin/env bash
# Post-installation script to commit hardware configuration
# Run this after successful first boot to save the hardware config to the repository

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}🔵 [INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}✨ [SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}⚠️  [WARN]${NC} $*"; }
log_error() { echo -e "${RED}💥 [ERROR]${NC} $*"; }

echo "📝 Hardware Configuration Commit Utility"
echo "========================================"
echo

# Check if we're in a git repository
if ! git rev-parse --git-dir >/dev/null 2>&1; then
    log_error "Not in a git repository. Please run this from your nix-configurations directory."
    exit 1
fi

# Get the hostname to determine machine name
HOSTNAME=$(hostname)
HARDWARE_CONFIG_SOURCE="/etc/nixos/hardware-configuration.nix"
HARDWARE_CONFIG_TARGET="machines/$HOSTNAME/hardware-configuration.nix"

log_info "Detected hostname: $HOSTNAME"

# Check if source hardware config exists
if [[ ! -f "$HARDWARE_CONFIG_SOURCE" ]]; then
    log_error "Hardware configuration not found at $HARDWARE_CONFIG_SOURCE"
    exit 1
fi

# Check if target directory exists
if [[ ! -d "machines/$HOSTNAME" ]]; then
    log_error "Machine directory machines/$HOSTNAME does not exist"
    log_info "Available machines:"
    ls -1 machines/ | grep -v templates || echo "  (none found)"
    exit 1
fi

# Copy the hardware configuration
log_info "Copying hardware configuration..."
cp "$HARDWARE_CONFIG_SOURCE" "$HARDWARE_CONFIG_TARGET"

# Verify it contains UUIDs
if grep -q "by-uuid" "$HARDWARE_CONFIG_TARGET"; then
    log_success "Hardware config contains UUIDs (good)"
else
    log_warn "Hardware config may contain labels instead of UUIDs"
fi

# Show what we're about to commit
echo
log_info "Hardware configuration to be committed:"
echo "----------------------------------------"
head -20 "$HARDWARE_CONFIG_TARGET" | grep -E "(device|fsType|options)" || true
echo "----------------------------------------"
echo

# Ask for confirmation
read -p "Commit this hardware configuration? [y/N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted by user"
    exit 0
fi

# Commit the hardware configuration
log_info "Committing hardware configuration..."
git add "$HARDWARE_CONFIG_TARGET"

if git commit -m "Add hardware configuration for $HOSTNAME

Generated on $(date)
- Hardware-specific UUIDs and device paths
- BTRFS subvolume configuration
- Boot loader settings"; then
    log_success "Hardware configuration committed successfully!"
    
    # Ask about pushing
    echo
    read -p "Push to remote repository? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if git push; then
            log_success "Changes pushed to remote repository"
        else
            log_warn "Failed to push - you may need to push manually later"
        fi
    fi
else
    log_error "Failed to commit hardware configuration"
    exit 1
fi

echo
log_success "Hardware configuration successfully saved to repository!"
log_info "Your machine configuration is now complete and backed up."
