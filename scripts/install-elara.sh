#!/usr/bin/env -S bash -Eeuo pipefail
# « install-elara.sh » – skinny wrapper around the generic installer

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# --- Elara-specific defaults ---
MACHINE="elara"            # flake output name
DEFAULT_FS="btrfs"         # can be overridden with --filesystem …
DEFAULT_BRANCH="main"      # or --branch …

# Gather user-supplied flags *after* we inject Elara’s defaults.
# Users can still override anything on the command line.
set -- \
  --machine   "$MACHINE" \
  --filesystem "$DEFAULT_FS" \
  --branch    "$DEFAULT_BRANCH" \
  "$@"

# Delegate to the generic installer living in the same scripts directory
exec "$SCRIPT_DIR/install_machine.sh" "$@"
