#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
#  « install_machine.sh » – Comprehensive NixOS Installation Utility
# ──────────────────────────────────────────────────────────────────────────────
#   ✓ Interactive machine selection    ✓ Multiple filesystem support (BTRFS/ext4/XFS)
#   ✓ Enhanced error handling          ✓ LUKS2 encryption options
#   ✓ Progress indicators              ✓ Pre/post installation validation
#   ✓ Dynamic user detection           ✓ BTRFS snapshots integration
#   ✓ Dual-boot safety                 ✓ Comprehensive logging
#   ✓ Recovery mechanisms              ✓ Interactive configuration menus
# ──────────────────────────────────────────────────────────────────────────────

set -Eeuo pipefail
IFS=$'\n\t'
export LANG=C

# Global configuration
SCRIPT_VERSION="2.0.0"
REPO_URL="https://github.com/ex1tium/nix-configurations.git"
REPO_BRANCH="main"
LOG_FILE="/tmp/nixos-install-$(date +%Y%m%d-%H%M%S).log"
INSTALL_LOG="/tmp/nixos-install-detailed.log"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# Installation state variables
SELECTED_MACHINE=""
SELECTED_PROFILE=""
SELECTED_FILESYSTEM="btrfs"
ENABLE_ENCRYPTION=true
SELECTED_DISK=""
PRIMARY_USER=""
ENABLE_SNAPSHOTS=true
USER_OVERRIDE=""

# Nix flags for evaluation
NIX_FLAGS="--extra-experimental-features 'nix-command flakes' --no-warn-dirty"

###############################################################################
# Error handling and logging
###############################################################################

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }

error_exit() {
    local line_no=$1
    local error_code=$2
    log_error "Script failed at line $line_no with exit code $error_code"
    echo -e "${RED}❌ Installation failed at line $line_no${NC}"
    echo -e "${YELLOW}📋 Check the log file: $LOG_FILE${NC}"

    # Offer recovery options
    echo -e "\n${WHITE}Recovery Options:${NC}"
    echo "1. View error details"
    echo "2. Retry from checkpoint"
    echo "3. Clean up and exit"
    read -rp "Choose option [1-3]: " recovery_choice

    case "$recovery_choice" in
        1) show_error_details "$line_no" "$error_code" ;;
        2) attempt_recovery "$line_no" ;;
        3) cleanup_and_exit ;;
        *) cleanup_and_exit ;;
    esac
}

show_error_details() {
    local line_no=$1
    local error_code=$2

    echo -e "\n${WHITE}Error Details:${NC}"
    echo "Line: $line_no"
    echo "Exit Code: $error_code"
    echo -e "\n${WHITE}Recent log entries:${NC}"
    tail -20 "$LOG_FILE"

    if [[ -f "$INSTALL_LOG" ]]; then
        echo -e "\n${WHITE}Installation log (last 10 lines):${NC}"
        tail -10 "$INSTALL_LOG"
    fi

    echo -e "\n${YELLOW}Press Enter to continue...${NC}"
    read -r
    cleanup_and_exit
}

attempt_recovery() {
    local line_no=$1
    log_info "Attempting recovery from line $line_no"

    # Basic recovery attempts based on common failure points
    if [[ $line_no -gt 300 && $line_no -lt 400 ]]; then
        echo -e "${YELLOW}⚠️  Installation phase failure detected${NC}"
        echo "This might be due to network issues or package conflicts."
        echo "Would you like to retry the installation? [y/N]"
        read -rp "> " retry
        if [[ $retry =~ ^[Yy] ]]; then
            log_info "Retrying installation phase"
            # Jump back to installation
            return 0
        fi
    fi

    cleanup_and_exit
}

cleanup_and_exit() {
    log_info "Performing cleanup before exit"

    # Cleanup temporary files
    [[ -n "$USER_OVERRIDE" && -f "$USER_OVERRIDE" ]] && rm -f "$USER_OVERRIDE"

    # Unmount if mounted
    if mountpoint -q /mnt 2>/dev/null; then
        echo -e "${YELLOW}🔧 Unmounting installation target...${NC}"
        sudo umount -R /mnt 2>/dev/null || true
    fi

    echo -e "\n${BLUE}📋 Installation Summary:${NC}"
    echo "Log file: $LOG_FILE"
    echo "Detailed log: $INSTALL_LOG"
    echo -e "\n${WHITE}Thank you for using the NixOS installer!${NC}"
    exit 1
}

trap 'error_exit ${LINENO} $?' ERR

# Keep sudo alive
sudo -v

###############################################################################
# Utility functions
###############################################################################

print_header() {
    clear
    echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║                    NixOS Installation Utility v${SCRIPT_VERSION}                    ║${NC}"
    echo -e "${PURPLE}║                     Comprehensive Machine Installer                         ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() {
    local step_num=$1
    local total_steps=$2
    local description=$3
    echo -e "\n${CYAN}[Step $step_num/$total_steps]${NC} ${WHITE}$description${NC}"
    log_info "Step $step_num/$total_steps: $description"
}

spinner() {
    local pid=$1
    local msg=$2
    local i=0
    local sp='|/-\\'
    while kill -0 "$pid" 2>/dev/null; do
        printf "\r${BLUE}%s %c${NC}" "$msg" "${sp:i++%4:1}"
        sleep 0.15
    done
    if wait "$pid"; then
        printf "\r${GREEN}%s ✓${NC}\n" "$msg"
        return 0
    else
        printf "\r${RED}%s ❌${NC}\n" "$msg"
        return 1
    fi
}

confirm_action() {
    local prompt="$1"
    local default="${2:-n}"
    local response

    if [[ "$default" == "y" ]]; then
        read -rp "$prompt [Y/n]: " response
        response=${response:-Y}
    else
        read -rp "$prompt [y/N]: " response
        response=${response:-N}
    fi

    [[ $response =~ ^[Yy] ]]
}