#!/usr/bin/env bash
# Quick fix for BTRFS subvolume permission issues during installation

set -euo pipefail

# Load common functions
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

main() {
    print_box "$CYAN" "🔧 BTRFS Subvolume Permission Fix 🔧" \
        "${WHITE}This script will fix permission issues with BTRFS subvolumes" \
        "${YELLOW}Run this if the installation failed at subvolume verification"
    echo

    # Check if we're in the right context
    if [[ ! -d /mnt ]]; then
        log_error "/mnt directory not found - are you in an installation context?"
        exit 1
    fi

    # Check if subvolumes are mounted
    local mount_points=("/mnt" "/mnt/home" "/mnt/nix" "/mnt/.snapshots")
    local all_mounted=true

    for mount_point in "${mount_points[@]}"; do
        if ! mountpoint -q "$mount_point" 2>/dev/null; then
            log_warn "$mount_point is not mounted"
            all_mounted=false
        fi
    done

    if [[ "$all_mounted" == "false" ]]; then
        log_error "Not all subvolumes are mounted. Please run the installation script first."
        exit 1
    fi

    # Fix permissions on all subvolumes
    log_info "Fixing permissions on BTRFS subvolumes..."

    for mount_point in "${mount_points[@]}"; do
        log_info "Setting permissions on $mount_point..."
        
        # Set directory permissions
        if chmod 755 "$mount_point" 2>/dev/null; then
            log_success "✅ Fixed permissions on $mount_point"
        else
            log_warn "⚠️  Could not set permissions on $mount_point"
        fi

        # Test write access
        local test_file="$mount_point/test_write_$$"
        if echo "test" > "$test_file" 2>/dev/null; then
            rm -f "$test_file"
            log_success "✅ $mount_point is now writable"
        else
            log_error "❌ $mount_point is still not writable"
        fi
    done

    echo
    log_success "Permission fix completed! You can now continue with the installation."
    log_info "If the installation script is still running, it should proceed normally."
}

main "$@"
