# TODO(andywang): add comment

F_NULL='<<null>>'

# TODO(andywang): add comment
f_prepare_args() {
  local out
  for out in "$@"; do
    printf -v "f_arg_${out}" '%s' "$F_NULL"
  done
}

# TODO(andywang): add comment
f_end() {
  local fn="$1" out var
  shift
  for out in "$@"; do
    var="f_arg_${out}"
    if [[ -z "${!var+x}" || "${!var}" == "$F_NULL" ]]; then
      error "$fn: output '$var' was not initialized"
    fi
  done
}

# TODO(andywang): add comment
f_with_args() {
  local fn="$1" outs=""
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    outs+="${outs:+ }$1"
    shift
  done
  [[ $# -gt 0 ]] && shift
  [[ -n "$outs" ]] || error "f_with_args $fn: no outputs given"
  f_prepare_args $outs
  "$fn" "$@"
  f_end "$fn" $outs
}

# TODO(andywang): add comment
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
