# Inferring the variant (the OS dimension) and the machine to install for from the running system (see --infer in
# README.md). The *_for_* functions are pure; infer_system reads the system and passes what it finds to them.

# Machines --machine accepts. generic is any hardware without its own features; the rest are @machine values.
MACHINES="generic framework16"
OS_RELEASE_FILE=/etc/os-release
DMI_ID_DIR=/sys/class/dmi/id

# Print the variant for kernel name $1 (uname -s), os-release ID $2 and ID_LIKE $3 (a list), with $4 true inside a
# Coder workspace, or nothing if no variant fits. Coder wins over the OS, which is just the workspace's image; other
# Linux systems (Ubuntu, WSL, ...) and macOS get the portable variant.
variant_for_system() {
  local kernel="$1" id="$2" id_like="$3" coder="$4"
  if [[ "$coder" == true ]]; then
    echo coder
    return
  fi
  case "$kernel" in
    Darwin) echo portable ;;
    Linux)
      # SteamOS is ID_LIKE=arch, so check it first.
      if [[ "$id" == steamos ]]; then
        echo steamos
      elif [[ "$id" == arch ]] || list_contains "$id_like" arch; then
        echo arch
      else
        echo portable
      fi
      ;;
  esac
}

# Print the machine for DMI system vendor $1 and product name $2 (empty when unknown, e.g. on macOS).
machine_for_dmi() {
  case "$1:$2" in
    "Framework:Laptop 16"*) echo framework16 ;;
    *)                      echo generic ;;
  esac
}

# Outputs: _id and _id_like, the ID and ID_LIKE fields of os-release file $1, unquoted (empty if missing). The file is
# parsed rather than sourced, so it can't run anything.
read_os_release() {
  local file="$1" line key value id="" id_like=""
  if [[ -r "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      key="${line%%=*}"
      value="${line#*=}"
      value="${value#[\"\']}"
      value="${value%[\"\']}"
      case "$key" in
        ID)      id="$value" ;;
        ID_LIKE) id_like="$value" ;;
      esac
    done < "$file"
  fi
  _id="$id"
  _id_like="$id_like"
}

# Outputs: _variant and _machine, what this system looks like (_variant is empty if no variant fits), and _reason,
# what they were inferred from, for messages. Reads uname, OS_RELEASE_FILE, DMI_ID_DIR and the CODER variable that
# Coder sets in its workspaces.
infer_system() {
  local kernel vendor="" product="" coder=false
  kernel="$(uname -s)"
  [[ "${CODER:-}" != true ]] || coder=true
  f_write_args read_os_release _id _id_like -- "$OS_RELEASE_FILE"
  if [[ -r "$DMI_ID_DIR/sys_vendor" ]]; then
    vendor="$(cat "$DMI_ID_DIR/sys_vendor")"
    product="$(cat "$DMI_ID_DIR/product_name" 2>/dev/null || true)"
  fi
  _variant="$(variant_for_system "$kernel" "$_id" "$_id_like" "$coder")"
  _machine="$(machine_for_dmi "$vendor" "$product")"
  if $coder; then
    _reason="Coder workspace"
  else
    _reason="$kernel${_id:+ $_id}"
  fi
  _reason+="${vendor:+, $vendor${product:+ $product}}"
}
