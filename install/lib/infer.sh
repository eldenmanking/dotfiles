# Inferring the OS, profile and machine to install for from the running system (see --infer in README.md). The *_for_*
# functions are pure; infer_system reads the system and passes what it finds to them.

# Machines --machine accepts (each OS supports some, see os_config). generic is any hardware without its own features;
# the rest are @machine values.
MACHINES="generic framework16"
OS_RELEASE_FILE=/etc/os-release
DMI_ID_DIR=/sys/class/dmi/id

# Print the OS for kernel name $1 (uname -s), os-release ID $2 and ID_LIKE $3 (a list), with $4 true inside a
# Coder workspace, or nothing if no OS fits. A Coder workspace is portable whatever its image, since the workspace
# profile only runs there; other Linux systems (Ubuntu, WSL, ...) and macOS are portable too.
os_for_system() {
  local kernel="$1" id="$2" id_like="$3" coder="$4"
  if [[ "$coder" == true ]]; then
    echo portable
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

# Print the profile for OS $1, with $2 true inside a Coder workspace: workspace there, desktop on arch and steamos
# (installs there set up the desktop too, so an Arch install without one yet still gets it), minimal elsewhere.
profile_for_system() {
  local os="$1" coder="$2"
  case "$os" in
    arch|steamos) echo desktop ;;
    portable)     if [[ "$coder" == true ]]; then echo workspace; else echo minimal; fi ;;
  esac
}

# Print the machine for DMI system vendor $1 and product name $2 (empty when unknown, e.g. on macOS).
machine_for_dmi() {
  case "$1:$2" in
    "Framework:Laptop 16"*) echo framework16 ;;
    *)                      echo generic ;;
  esac
}

# Outputs: id and id_like, the ID and ID_LIKE fields of os-release file $1, unquoted (empty if missing). The file is
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
  f_return id="$id" id_like="$id_like"
}

# Outputs: os and machine, what this system looks like (os is empty if no OS fits), coder, true inside a Coder
# workspace (for profile_for_system), and reason, what they were inferred from, for messages. Reads uname,
# OS_RELEASE_FILE, DMI_ID_DIR and the CODER variable that Coder sets in its workspaces.
infer_system() {
  local kernel vendor="" product="" coder=false id id_like reason
  kernel="$(uname -s)"
  [[ "${CODER:-}" != true ]] || coder=true
  f_call read_os_release id id_like -- "$OS_RELEASE_FILE"
  if [[ -r "$DMI_ID_DIR/sys_vendor" ]]; then
    vendor="$(cat "$DMI_ID_DIR/sys_vendor")"
    product="$(cat "$DMI_ID_DIR/product_name" 2>/dev/null || true)"
  fi
  if $coder; then
    reason="Coder workspace"
  else
    reason="$kernel${id:+ $id}"
  fi
  reason+="${vendor:+, $vendor${product:+ $product}}"
  f_return \
    os="$(os_for_system "$kernel" "$id" "$id_like" "$coder")" \
    machine="$(machine_for_dmi "$vendor" "$product")" \
    coder="$coder" \
    reason="$reason"
}
