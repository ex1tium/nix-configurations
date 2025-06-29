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
# 8. Disk and partition helpers
# -----------------------------------------------------------------------------#
list_disks() { lsblk -dn -o NAME,TYPE | awk '$2=="disk"{print "/dev/"$1}'; }

check_free_space() {                # check_free_space <disk> [min_gb]
    local disk=$1 min_gb=${2:-20}
    local free_gb

    # Get largest free space in GB
    free_gb=$(parted "$disk" unit GB print free 2>/dev/null |
              awk '/Free Space/ {gsub(/GB/,"",$3); if($3>max) max=$3} END{print int(max)}')

    if [[ -z $free_gb ]] || (( free_gb < min_gb )); then
        log_error "Insufficient free space: ${free_gb}GB (need ${min_gb}GB)"
        return 1
    fi

    log_info "Found ${free_gb}GB free space"
    return 0
}

detect_esp_partition() {            # detect_esp_partition <disk>
    lsblk -o NAME,PARTTYPE "$1" 2>/dev/null |
    awk '$2 ~ /c12a7328-f81f-11d2-ba4b-00a0c93ec93b/ {print "/dev/"$1; exit}'
}

# -----------------------------------------------------------------------------#
# 9. Nix helpers
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

validate_nix_build() {             # validate_nix_build <flake_ref>
    local flake_ref=$1 flags; flags=$(get_nix_flags)
    log_info "Validating configuration build: $flake_ref"

    if is_dry_run; then
        log_info "DRY-RUN: Would validate build for $flake_ref"
        return 0
    fi

    if ! nix $flags build --dry-run "$flake_ref" &>/tmp/build_test.log; then
        log_error "Configuration build validation failed"
        [[ -f /tmp/build_test.log ]] && tail -20 /tmp/build_test.log >&2
        return 1
    fi

    log_info "Configuration build validation successful"
    return 0
}

# -----------------------------------------------------------------------------#
# 10. System validation and setup helpers
# -----------------------------------------------------------------------------#
validate_installation_environment() {
    log_info "Validating installation environment"

    # Check if running as root (should not be)
    if (( EUID == 0 )); then
        log_error "Do not run as root. Run as normal user with sudo access."
        return 1
    fi

    # Test sudo access (unless dry-run)
    if ! is_dry_run && ! sudo -v; then
        log_error "Sudo access required for installation"
        return 1
    fi

    # Check if on NixOS ISO (warn if not)
    if [[ ! -f /etc/NIXOS ]]; then
        log_warn "Not running on NixOS ISO - some features may not work"
        if ! confirm_action "Continue anyway?"; then
            return 1
        fi
    fi

    # Check network connectivity
    if ! check_network_connectivity; then
        log_error "Network connectivity required for installation"
        return 1
    fi

    # Check boot mode
    local boot_mode; boot_mode=$(detect_boot_mode)
    log_info "Boot mode: $boot_mode"

    log_info "Environment validation completed"
    return 0
}

bootstrap_nix_dependencies() {      # bootstrap_nix_dependencies <packages...>
    local packages=("$@")
    local missing=() cmd

    log_info "Checking dependencies: ${packages[*]}"

    # Check which packages are missing
    for pkg in "${packages[@]}"; do
        case $pkg in
            util-linux) cmd=lsblk ;;
            gptfdisk) cmd=sgdisk ;;
            *) cmd=$pkg ;;
        esac

        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    # If packages are missing, re-exec with nix-shell
    if (( ${#missing[@]} > 0 )); then
        log_info "Installing missing dependencies: ${missing[*]}"
        # This will cause the script to re-exec with dependencies
        return 2  # Special return code indicating re-exec needed
    fi

    log_info "All dependencies available"
    return 0
}

setup_config_repository() {         # setup_config_repository <url> <branch> [target_dir]
    local repo_url=$1 branch=$2 target_dir=${3:-/tmp/nix-config}

    log_info "Setting up configuration repository"
    log_info "Repository: $repo_url (branch: $branch)"

    # Clean up any existing directory
    [[ -d $target_dir ]] && rm -rf "$target_dir"

    if is_dry_run; then
        log_info "DRY-RUN: Would clone $repo_url to $target_dir"
        mkdir -p "$target_dir/machines/example"
        echo '{ }' > "$target_dir/machines/example/configuration.nix"
        return 0
    fi

    # Clone repository in background with spinner
    (git clone --depth 1 --branch "$branch" "$repo_url" "$target_dir" &>/tmp/git_clone.log) &
    local clone_pid=$!

    if command -v spinner &>/dev/null; then
        spinner $clone_pid "Cloning repository"
    else
        wait $clone_pid
    fi

    local clone_status=$?
    if (( clone_status != 0 )); then
        log_error "Failed to clone repository"
        [[ -f /tmp/git_clone.log ]] && tail -10 /tmp/git_clone.log >&2
        return 1
    fi

    log_info "Repository cloned successfully to $target_dir"
    return 0
}

discover_machine_configs() {        # discover_machine_configs [machines_dir]
    local machines_dir=${1:-machines}
    local -a discovered_machines

    log_info "Discovering machine configurations in $machines_dir"

    if [[ ! -d $machines_dir ]]; then
        log_error "Machines directory not found: $machines_dir"
        return 1
    fi

    mapfile -t discovered_machines < <(
        find "$machines_dir" -maxdepth 1 -mindepth 1 -type d ! -name templates -printf '%P\n' | sort
    )

    if (( ${#discovered_machines[@]} == 0 )); then
        log_error "No machine configurations found in $machines_dir"
        return 1
    fi

    log_info "Found ${#discovered_machines[@]} machine configurations: ${discovered_machines[*]}"

    # Export for use by calling script
    printf '%s\n' "${discovered_machines[@]}"
    return 0
}

# -----------------------------------------------------------------------------#
# 11. User configuration helpers
# -----------------------------------------------------------------------------#
setup_user_override() {            # setup_user_override <machine> <username> [current_user]
    local machine=$1 username=$2 current_user=${3:-}
    local override_file="machines/$machine/_user-override.nix"

    # Detect current user if not provided
    if [[ -z $current_user ]]; then
        current_user=$(detect_primary_user_from_flake .)
    fi

    # Only create override if username differs from detected user
    if [[ $username != "$current_user" ]]; then
        log_info "Creating user override: $username (was: $current_user)"

        if ! is_dry_run; then
            echo "{ ... }: { mySystem.user = \"$username\"; }" > "$override_file"
        fi

        echo "$override_file"  # Return the override file path
    fi

    return 0
}

# -----------------------------------------------------------------------------#
# 12. Partition management helpers
# -----------------------------------------------------------------------------#
create_fresh_partitions() {        # create_fresh_partitions <disk>
    local disk=$1

    log_info "Creating fresh GPT partition table on $disk"

    if is_dry_run; then
        log_info "DRY-RUN: Would create fresh partitions on $disk"
        return 0
    fi

    # Create GPT table and partitions
    sudo parted -s "$disk" \
        mklabel gpt \
        mkpart ESP fat32 1MiB 512MiB \
        set 1 esp on \
        mkpart primary 512MiB 100%

    # Probe partitions and wait for device nodes
    sudo partprobe "$disk"
    sleep 2

    # Format ESP
    sudo mkfs.fat -F32 -n boot "${disk}1"

    log_info "Fresh partitions created successfully"
    return 0
}

create_dual_boot_partitions() {    # create_dual_boot_partitions <disk>
    local disk=$1 esp_partition

    log_info "Setting up dual-boot partitions on $disk"

    # Check free space first
    if ! check_free_space "$disk" 20; then
        return 1
    fi

    # Detect or create ESP
    esp_partition=$(detect_esp_partition "$disk")

    if [[ -z $esp_partition ]]; then
        log_info "No ESP found, creating new ESP"

        if ! is_dry_run; then
            # Find end of last partition
            local last_end
            last_end=$(parted "$disk" unit MiB print | awk '/^ /{end=$3} END{print end}' | sed 's/MiB//')
            last_end=${last_end:-1}

            # Create ESP
            sudo parted -s "$disk" mkpart ESP fat32 "$((last_end+1))MiB" "$((last_end+513))MiB"
            local esp_num
            esp_num=$(parted "$disk" print | awk '/^ /{n=$1} END{print n}')
            sudo parted -s "$disk" set "$esp_num" esp on

            esp_partition="${disk}${esp_num}"
            sudo mkfs.fat -F32 -n boot "$esp_partition"
        else
            esp_partition="${disk}1"  # Placeholder for dry-run
        fi
    else
        log_info "Found existing ESP: $esp_partition"
    fi

    # Create root partition in free space
    if ! is_dry_run; then
        local free_start free_end
        read -r free_start free_end < <(
            parted "$disk" unit MiB print free |
            awk '/Free Space/ {s=$1; e=$2} END{print s,e}' |
            sed 's/MiB//g'
        )

        sudo parted -s "$disk" mkpart primary "${free_start}MiB" 100%
        sudo partprobe "$disk"
        sleep 2
    fi

    # Return ESP partition for mounting
    echo "$esp_partition"
    return 0
}

get_root_partition() {              # get_root_partition <disk> <mode>
    local disk=$1 mode=$2

    case $mode in
        fresh)
            # Second partition in fresh install
            lsblk -lnpo NAME "$disk" | sort -V | sed -n '2p'
            ;;
        dual-boot)
            # Last partition (newly created)
            lsblk -lnpo NAME "$disk" | sort -V | tail -1
            ;;
        *)
            log_error "Invalid partition mode: $mode"
            return 1
            ;;
    esac
}
