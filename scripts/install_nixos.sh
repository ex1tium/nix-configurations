#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  « install_nixos.sh » – NixOS installer with automatic dependency management
#      • Automatically provides all required dependencies via nix-shell
#      • Single terminal session - no re-execution
#      • Clear error reporting and progress indication
# ──────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# Required packages for the installer
REQUIRED_PACKAGES=(git parted util-linux gptfdisk cryptsetup rsync tar jq bc)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                          NixOS Installation Utility                          ║${NC}"
    echo -e "${BLUE}║                          with Automatic Dependencies                         ║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo
}

check_nix_available() {
    if ! command -v nix-shell &>/dev/null; then
        echo -e "${RED}ERROR: nix-shell not available${NC}"
        echo "This script requires Nix to be installed and available."
        echo "Please run this on a NixOS Live CD or system with Nix installed."
        exit 1
    fi
}

detect_target_script() {
    # Check if user wants elara-specific installation
    if [[ "${1:-}" == "--elara" ]] || [[ "${1:-}" == "elara" ]]; then
        echo "$SCRIPT_DIR/install-elara.sh"
        shift # Remove the elara flag from arguments
    else
        echo "$SCRIPT_DIR/install_machine.sh"
    fi
}

main() {
    print_header
    
    echo -e "${BLUE}[INFO]${NC} Checking Nix availability..."
    check_nix_available
    
    echo -e "${BLUE}[INFO]${NC} Detecting target installation script..."
    TARGET_SCRIPT=$(detect_target_script "$@")
    
    if [[ ! -f "$TARGET_SCRIPT" ]]; then
        echo -e "${RED}ERROR: Installation script not found: $TARGET_SCRIPT${NC}"
        echo "Please ensure you're running this from the nix-configurations directory."
        exit 1
    fi
    
    echo -e "${BLUE}[INFO]${NC} Target script: $(basename "$TARGET_SCRIPT")"
    echo -e "${BLUE}[INFO]${NC} Loading Nix environment with required packages..."
    echo -e "${YELLOW}[WAIT]${NC} This may take a moment to download packages..."
    echo
    
    # Execute the target script with all required dependencies
    exec nix-shell -p "${REQUIRED_PACKAGES[@]}" --run "bash '$TARGET_SCRIPT' $*"
}

# Show usage if help requested
if [[ "${1:-}" =~ ^(-h|--help|help)$ ]]; then
    print_header
    echo "Usage: $0 [elara|--elara] [install_machine.sh options]"
    echo
    echo "Examples:"
    echo "  $0                          # Interactive installation"
    echo "  $0 elara                    # Elara-specific installation"
    echo "  $0 --machine elara --disk /dev/sda --encrypt"
    echo "  $0 --dry-run --mode fresh --machine elara"
    echo
    echo "This wrapper automatically provides all required dependencies via nix-shell."
    echo "All options are passed through to the underlying installation script."
    echo
    exit 0
fi

main "$@"
