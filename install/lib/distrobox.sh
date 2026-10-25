# Distrobox helpers shared by the distrobox and steamos_xclip features.

DISTROBOX_NAME="arch"
DISTROBOX_IMAGE="archlinux:latest"

# Return 0 if a distrobox named $1 exists. Matches the NAME column exactly, so
# 'arch' doesn't match e.g. 'tmp-arch'.
distrobox_exists() {
  distrobox list --no-color 2>/dev/null \
    | awk -F'|' -v name="$1" 'NR > 1 { gsub(/^ +| +$/, "", $2); if ($2 == name) found = 1 } END { exit !found }'
}
