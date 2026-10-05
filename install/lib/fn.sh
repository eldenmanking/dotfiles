# TODO(andywang): add comment

F_NULL='<<null>>'

# TODO(andywang): add comment
f_prepare_args() {
  local fn="$1" out
  shift
  for out in "$@"; do
    printf -v "f_${fn}_${out}" '%s' "$F_NULL"
  done
}

# TODO(andywang): add comment
f_begin() {
  local fn="$1" out var
  shift
  for out in "$@"; do
    var="f_${fn}_${out}"
    if [[ -z "${!var+x}" ]]; then
      error "$fn: output '$var' was not prepared (call 'f_prepare_args $fn $*' first)"
    fi
    if [[ "${!var}" != "$F_NULL" ]]; then
      error "$fn: output '$var' is already initialized (call 'f_prepare_args $fn $*' first)"
    fi
  done
}

# TODO(andywang): add comment
f_end() {
  local fn="$1" out var
  shift
  for out in "$@"; do
    var="f_${fn}_${out}"
    if [[ -z "${!var+x}" || "${!var}" == "$F_NULL" ]]; then
      error "$fn: output '$var' was not initialized"
    fi
  done
}

# TODO(andywang): add comment
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
