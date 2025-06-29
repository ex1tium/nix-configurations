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
    local ts level=$1 color emoji; shift
    ts=$(date '+%Y-%m-%d %H:%M:%S')

    # Set color and emoji based on log level
    case $level in
        ERROR)   color=$RED;    emoji="💥" ;;
        WARN)    color=$YELLOW; emoji="⚠️ " ;;
        SUCCESS) color=$GREEN;  emoji="✨" ;;
        INFO)    color=$CYAN;   emoji="🔵" ;;
        DEBUG)   color=$PURPLE; emoji="🔍" ;;
        STEP)    color=$BLUE;   emoji="🚀" ;;
        *)       color=$NC;     emoji="📝" ;;
    esac

    # Log to file without colors/emojis
    printf '[%s] [%s] %s\n' "$ts" "$level" "$*" >> "$LOG_FILE"

    # Display with colors and emojis to stderr
    printf '%s%s [%s]%s %s\n' "$color" "$emoji" "$level" "$NC" "$*" >&2
}
log_info()    { _log INFO    "$*"; }
log_warn()    { _log WARN    "$*"; }
log_error()   { _log ERROR   "$*"; }
log_success() { _log SUCCESS "$*"; }
log_step()    { _log STEP    "$*"; }
log_debug()   { [[ $DEBUG == 1 ]] && _log DEBUG "$*"; }

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

    # Dynamic box dimensions based on terminal width
    local term_width=$(get_terminal_width)
    local box_width=$((term_width > 100 ? 100 : term_width - 4))
    local inner_width=$((box_width - 2))

    # Get appropriate box characters
    local box_chars=$(get_box_chars)
    local tl=${box_chars:0:1} hr=${box_chars:1:1} tr=${box_chars:2:1}
    local vr=${box_chars:3:1} bl=${box_chars:4:1} br=${box_chars:5:1}

    # Prepare title with emojis
    local title_with_emoji="🚀 ${title} 🚀"
    local ver_text=""
    if [[ -n $ver ]]; then
        ver_text="✨ v${ver} ✨"
    fi

    clear
    echo
    # Beautiful header with proper width calculations
    echo "${CYAN}${tl}$(printf '%*s' "$((box_width-2))" '' | tr ' ' "${hr}")${tr}${NC}"
    echo "${CYAN}${vr}$(printf '%*s' "$inner_width" '')${vr}${NC}"
    echo "${CYAN}${vr}$(center_text "${WHITE}${title_with_emoji}${CYAN}" "$inner_width")${vr}${NC}"

    if [[ -n $ver_text ]]; then
        echo "${CYAN}${vr}$(center_text "${YELLOW}${ver_text}${CYAN}" "$inner_width")${vr}${NC}"
    else
        echo "${CYAN}${vr}$(printf '%*s' "$inner_width" '')${vr}${NC}"
    fi

    echo "${CYAN}${vr}$(printf '%*s' "$inner_width" '')${vr}${NC}"
    echo "${CYAN}${bl}$(printf '%*s' "$((box_width-2))" '' | tr ' ' "${hr}")${br}${NC}"
    echo
}

print_step() {                      # print_step <n> <total> <desc>
    if ! (( QUIET )); then
        local step_text="Step $1/$2"
        local desc="$3"
        local percentage=$(( ($1 * 100) / $2 ))

        # Dynamic width calculation
        local term_width=$(get_terminal_width)
        local box_width=$((term_width > 80 ? 80 : term_width - 4))
        local inner_width=$((box_width - 2))

        # Progress bar calculation (scale to fit available space)
        local bar_width=20  # Fixed width for consistency
        local progress=$(( ($1 * bar_width) / $2 ))

        # Get box characters
        local box_chars=$(get_box_chars)
        local tl=${box_chars:8:1} hr=${box_chars:7:1} tr=${box_chars:9:1}
        local vr=${box_chars:6:1} bl=${box_chars:10:1} br=${box_chars:11:1}

        # Progress bar characters (always use ASCII for better compatibility)
        local filled=$(printf '%*s' "$progress" '' | tr ' ' '#')
        local empty=$(printf '%*s' "$((bar_width - progress))" '' | tr ' ' '-')

        # Calculate header padding
        local step_desc="$step_text - $desc"
        local header_content_width=$(text_width "$step_desc")
        local header_padding=$((box_width - header_content_width - 6))
        (( header_padding < 0 )) && header_padding=0

        echo
        echo -e "${CYAN}${tl}${hr}${hr} ${WHITE}${step_text}${CYAN} ${hr} ${WHITE}${desc}${CYAN} $(printf '%*s' "$header_padding" '' | tr ' ' "${hr}")${tr}${NC}"
        echo -e "${CYAN}${vr} ${WHITE}🚀 [${GREEN}${filled}${empty}${WHITE}] ${percentage}%$(printf '%*s' "$((inner_width - 30))" '') ${CYAN}${vr}${NC}"
        echo -e "${CYAN}${bl}$(printf '%*s' "$((box_width-2))" '' | tr ' ' "${hr}")${br}${NC}"
    fi
    # Log to file only (no console output to avoid duplication)
    printf '[%s] [STEP] Step %s/%s: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" "$2" "$3" >> "$LOG_FILE"
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
# 4. Utilities & Graphics Helpers
# -----------------------------------------------------------------------------#
human_readable() {                  # human_readable <bytes>
    awk -v b="$1" 'BEGIN{
        split("B KB MB GB TB PB", u)
        for(i=1;b>=1024 && i<6;i++) b/=1024
        printf "%.1f%s", b, u[i]
    }'
}

# Graphics capability detection
has_unicode() {
    # Check for UTF-8 support and terminal capability
    [[ "${LANG:-}${LC_ALL:-}" =~ UTF-8 ]] && [[ -z "${NO_UNICODE:-}" ]] && [[ -t 1 ]] &&
    command -v locale &>/dev/null && locale charmap 2>/dev/null | grep -qi utf
}

# Terminal width detection
get_terminal_width() {
    local width
    if command -v tput &>/dev/null; then
        width=$(tput cols 2>/dev/null) || width=80
    else
        width=${COLUMNS:-80}
    fi
    # Ensure minimum width
    (( width < 60 )) && width=80
    echo "$width"
}

# Calculate text width (accounting for emojis and ANSI codes)
text_width() {
    local text="$1"
    # Remove ANSI escape sequences
    text=$(echo "$text" | sed 's/\x1b\[[0-9;]*m//g')
    # Emojis typically take 2 character widths in most terminals
    local emoji_count=$(echo "$text" | grep -o '[🚀✨🔵💥⚠️🔍🌳📁💾🖥️🤝🛠️💥🔐🎉📝]' | wc -l)
    local base_length=${#text}
    echo $(( base_length + emoji_count ))
}

# Center text within given width
center_text() {
    local text="$1" width="$2"
    local text_len=$(text_width "$text")
    local padding=$(( (width - text_len) / 2 ))
    (( padding < 0 )) && padding=0
    printf '%*s%s%*s' "$padding" '' "$text" "$((width - text_len - padding))" ''
}

# Box drawing characters (Unicode vs ASCII)
get_box_chars() {
    if has_unicode; then
        # Unicode box drawing: ╔═╗║╚╝│─┌┐└┘├┤┬┴┼
        echo "╔═╗║╚╝│─┌┐└┘├┤┬┴┼"
    else
        # ASCII fallback:      +=+|++|--++++++++
        echo "+=+|++|--+++++++++"
    fi
}

# Create a formatted box with content
print_box() {                      # print_box <color> <title> [content_lines...]
    local color="$1" title="$2"
    shift 2
    local content_lines=("$@")

    # Dynamic width calculation
    local term_width=$(get_terminal_width)
    local box_width=$((term_width > 100 ? 100 : term_width - 4))
    local inner_width=$((box_width - 2))

    # Get box characters
    local box_chars=$(get_box_chars)
    local tl=${box_chars:0:1} hr=${box_chars:1:1} tr=${box_chars:2:1}
    local vr=${box_chars:3:1} bl=${box_chars:4:1} br=${box_chars:5:1}

    # Top border
    echo -e "${color}${tl}$(printf '%*s' "$((box_width-2))" '' | tr ' ' "${hr}")${tr}${NC}"

    # Title (if provided)
    if [[ -n "$title" ]]; then
        echo -e "${color}${vr}$(center_text "${WHITE}${title}${color}" "$inner_width")${vr}${NC}"
        echo -e "${color}${vr}$(printf '%*s' "$inner_width" '')${vr}${NC}"
    fi

    # Content lines
    for line in "${content_lines[@]}"; do
        echo -e "${color}${vr}$(center_text "${line}${color}" "$inner_width")${vr}${NC}"
    done

    # Bottom border
    echo -e "${color}${bl}$(printf '%*s' "$((box_width-2))" '' | tr ' ' "${hr}")${br}${NC}"
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
    return 0
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
safe_unmount() {
    if mountpoint -q "$1"; then
        if is_dry_run; then
            log_info "DRY-RUN: Would unmount $1"
        else
            sudo umount -R "$1"
        fi
    fi
}

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
get_nix_flags() {
    local flags=(
        # Essential experimental features
        "--extra-experimental-features" "nix-command"
        "--extra-experimental-features" "flakes"

        # Installation-friendly options
        "--option" "warn-dirty" "false"           # Suppress dirty git warnings during installation
        "--option" "eval-cache" "false"           # Disable eval cache for fresh builds
        "--option" "pure-eval" "false"            # Allow impure evaluation for installation context
        "--option" "allow-import-from-derivation" "true"  # Allow IFD for complex builds

        # Performance and reliability
        "--option" "max-jobs" "auto"              # Use all available cores
        "--option" "cores" "0"                    # Use all available cores for building
        "--option" "keep-going" "true"            # Continue building other derivations on failure

        # Network and substitution
        "--option" "substitute" "true"            # Enable binary cache substitution
        "--option" "builders-use-substitutes" "true"  # Allow builders to use substitutes
    )
    echo "${flags[*]}"
}

# Specialized flags for different operations
get_nix_build_flags() {
    local base_flags; base_flags=$(get_nix_flags)
    echo "$base_flags --option build-timeout 3600"  # 1 hour timeout for builds
}

get_nix_eval_flags() {
    local base_flags; base_flags=$(get_nix_flags)
    echo "$base_flags --option restrict-eval false"  # Allow unrestricted evaluation
}

detect_primary_user_from_flake() {  # detect_primary_user_from_flake [dir]
    local dir=${1:-.} u flags; flags=$(get_nix_eval_flags)
    if command -v nix &>/dev/null; then
        u=$(nix $flags eval --impure --expr "((import $dir/.).globalConfig).defaultUser or \"\"" --raw 2>/dev/null)
        [[ -z $u ]] && u=$(nix $flags eval "$dir#globalConfig.defaultUser" --raw 2>/dev/null)
    fi
    [[ -z $u && -f $dir/flake.nix ]] && u=$(grep -o 'defaultUser *= *"[^"]*"' "$dir/flake.nix" | head -1 | cut -d'"' -f2)
    echo "${u:-nixos}"
}

validate_nix_build() {             # validate_nix_build <flake_ref>
    local flake_ref=$1 flags; flags=$(get_nix_build_flags)
    log_info "Validating configuration build: $flake_ref"

    if is_dry_run; then
        log_info "DRY-RUN: Would validate build for $flake_ref"
        return 0
    fi

    log_info "Using Nix flags for build validation..."
    if ! nix $flags build --dry-run "$flake_ref" &>/tmp/build_test.log; then
        log_error "Configuration build validation failed"
        log_error "Build log (last 20 lines):"
        [[ -f /tmp/build_test.log ]] && tail -20 /tmp/build_test.log >&2
        return 1
    fi

    log_success "Configuration build validation successful! ✅"
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

    # If packages are missing, provide clear instructions
    if (( ${#missing[@]} > 0 )); then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error ""
        log_error "Please run the installer with nix-shell to provide dependencies:"
        log_error ""
        log_error "  nix-shell -p ${packages[*]} --run './scripts/install_machine.sh'"
        log_error ""
        log_error "Or for the elara wrapper:"
        log_error "  nix-shell -p ${packages[*]} --run './scripts/install-elara.sh'"
        log_error ""
        return 1
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
