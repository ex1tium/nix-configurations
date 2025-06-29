#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
#  « lib/common.sh » – Shared helpers for NixOS installation utilities
# ──────────────────────────────────────────────────────────────────────────────

# Prevent double-sourcing
[[ -n "${NIXOS_INSTALLER_LIB_LOADED:-}" ]] && return 0
readonly NIXOS_INSTALLER_LIB_LOADED=1

# -----------------------------------------------------------------------------#
# 0. Defaults that must exist *before* helpers use them
# -----------------------------------------------------------------------------#
: "${LOG_FILE:=/tmp/nixos-install.log}"
: "${DRY_RUN:=0}"   "${NON_INTERACTIVE:=0}" "${FORCE_YES:=0}"
: "${QUIET:=0}"     "${DEBUG:=0}"
export LOG_FILE DRY_RUN NON_INTERACTIVE FORCE_YES QUIET DEBUG

shopt -s inherit_errexit lastpipe

# -----------------------------------------------------------------------------#
# 1. Colour handling – respect $NO_COLOR
# -----------------------------------------------------------------------------#
if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]] && command -v tput &>/dev/null; then
    readonly RED=$(tput setaf 1)    GREEN=$(tput setaf 2)
    readonly YELLOW=$(tput setaf 3) BLUE=$(tput setaf 4)
    readonly PURPLE=$(tput setaf 5) CYAN=$(tput setaf 6)
    readonly WHITE=$(tput setaf 7)  NC=$(tput sgr0)
else
    RED='' GREEN='' YELLOW='' BLUE='' PURPLE='' CYAN='' WHITE='' NC=''
fi

# -----------------------------------------------------------------------------#
# 2. Logging
# -----------------------------------------------------------------------------#
_log() {                             # _log <LEVEL> <msg…>
    local ts level=$1; shift
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] [%s] %s\n' "$ts" "$level" "$*" | tee -a "$LOG_FILE"
}
log_info()  { _log INFO  "$*"; }
log_warn()  { _log WARN  "$*"; }
log_error() { _log ERROR "$*"; }
log_debug() { [[ $DEBUG == 1 ]] && _log DEBUG "$*"; }

# -----------------------------------------------------------------------------#
# 3. User-interaction helpers
# -----------------------------------------------------------------------------#
confirm_action() {                  # confirm_action <prompt> [default=y|n]
    local prompt=$1 def=${2:-n} ans
    if (( NON_INTERACTIVE )) || (( FORCE_YES )); then
        [[ $def == y || $FORCE_YES == 1 ]]
        return
    fi
    if [[ $def == y ]]; then
        read -rp "$prompt [Y/n]: " ans; ans=${ans:-Y}
    else
        read -rp "$prompt [y/N]: " ans; ans=${ans:-N}
    fi
    [[ $ans =~ ^[Yy] ]]
}

print_header() {                    # print_header [title] [version]
    (( QUIET )) && return
    local title=${1:-NixOS Installation Utility}
    local ver=${2:-}
    clear
    printf '%s╔%0.s═%s╗%s\n' "$PURPLE" {1..78} "$NC" ''
    printf '%s║%*s%s%*s║%s\n' \
           "$PURPLE" $(( (78-${#title})/2 )) '' "$title" \
           $(( (79-${#title})/2 )) '' "$NC"
    [[ -n $ver ]] && printf '%s║%*sv%s%*s║%s\n' \
           "$PURPLE" $(( (78-${#ver}-1)/2 )) '' "$ver" \
           $(( (79-${#ver}-1)/2 )) '' "$NC"
    printf '%s╚%0.s═%s╝%s\n\n' "$PURPLE" {1..78} "$NC" ''
}

print_step() {                      # print_step <n> <total> <desc>
    (( QUIET )) || printf '\n%s[Step %s/%s]%s %s%s%s\n' \
        "$CYAN" "$1" "$2" "$NC" "$WHITE" "$3" "$NC"
    log_info "Step $1/$2: $3"
}

# Spinner (tty only)
spinner() {                          # spinner <pid> <message>
    (( QUIET )) && { wait "$1"; return $?; }
    local pid=$1 msg=$2 sp='|/-\' i=0
    (
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r%s%s %c%s' "$BLUE" "$msg" "${sp:i++%4:1}" "$NC"
            sleep 0.15
        done
    ) &
    local spin=$!; wait "$pid"; local s=$?
    kill "$spin" 2>/dev/null; wait "$spin" 2>/dev/null || true
    printf '\r\033[K%s%s %s%s\n' \
        "$([ $s -eq 0 ] && echo "$GREEN✓" || echo "$RED❌")" "$NC" "$msg" "$NC"
    return $s
}

# -----------------------------------------------------------------------------#
# 4. Utilities
# -----------------------------------------------------------------------------#
human_readable() {                  # human_readable <bytes>
    awk -v b="$1" 'BEGIN{
        split("B KB MB GB TB PB", u)
        for(i=1;b>=1024 && i<6;i++) b/=1024
        printf "%.1f%s", b, u[i]
    }'
}

is_dry_run() { (( DRY_RUN )); }
dry_run_cmd() {                     # dry_run_cmd <command…>
    if is_dry_run; then
        printf '%s[DRY-RUN]%s %q\n' "$YELLOW" "$NC" "$*"
        log_info "DRY-RUN: $*"
    else
        log_debug "Exec: $*"; "$@"
    fi
}

# -----------------------------------------------------------------------------#
# 5. System / environment probes
# -----------------------------------------------------------------------------#
detect_boot_mode() { [[ -d /sys/firmware/efi/efivars ]] && echo uefi || echo bios; }

check_network_connectivity() {
    local urls=( "https://nixos.org" "https://cache.nixos.org" "github.com" "8.8.8.8" )
    for u in "${urls[@]}"; do
        if [[ $u =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            ping -c1 -W3 "$u" &>/dev/null && return 0
        else
            curl -fsSL --head --connect-timeout 5 "$u" &>/dev/null && return 0
        fi
    done
    return 1
}

get_available_memory_gb()  { awk '/MemAvailable/ {print int($2/1024/1024)}' /proc/meminfo; }
get_available_disk_space_gb() { df "${1:-/tmp}" --output=avail | tail -1 | awk '{print int($1/1024/1024)}'; }

# -----------------------------------------------------------------------------#
# 6. Validation helpers
# -----------------------------------------------------------------------------#
validate_username() {               # validate_username <name>
    [[ ${#1} -le 32 && $1 =~ ^[a-z][a-z0-9_-]*$ ]] || return 1
    local rsv=(root bin daemon adm lp sync shutdown halt mail nobody nixbld nixos)
    printf '%s\n' "${rsv[@]}" | grep -qx "$1" && return 1
}
validate_disk_device() {            # validate_disk_device </dev/…>
    [[ -b $1 && ! $1 =~ [0-9]+$ && $1 =~ ^/dev/(sd|vd|hd|nvme) ]] || return 1
}

# -----------------------------------------------------------------------------#
# 7. Cleanup helpers
# -----------------------------------------------------------------------------#
cleanup_temp_files() {
    local f; for f in /tmp/{git_clone,flake_check,build_test}.log; do
        [[ -f $f ]] && rm -f "$f"
    done
}
safe_unmount() { mountpoint -q "$1" && dry_run_cmd sudo umount -R "$1"; }

# -----------------------------------------------------------------------------#
# 8. Nix helpers
# -----------------------------------------------------------------------------#
get_nix_flags() { echo "--extra-experimental-features 'nix-command flakes' --no-warn-dirty"; }

detect_primary_user_from_flake() {  # detect_primary_user_from_flake [dir]
    local dir=${1:-.} u flags; flags=$(get_nix_flags)
    if command -v nix &>/dev/null; then
        u=$(nix $flags eval --impure --expr "((import $dir/.).globalConfig).defaultUser or \"\"" --raw 2>/dev/null)
        [[ -z $u ]] && u=$(nix $flags eval "$dir#globalConfig.defaultUser" --raw 2>/dev/null)
    fi
    [[ -z $u && -f $dir/flake.nix ]] && u=$(grep -o 'defaultUser *= *"[^"]*"' "$dir/flake.nix" | head -1 | cut -d'"' -f2)
    echo "${u:-nixos}"
}
