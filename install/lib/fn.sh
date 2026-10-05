# Helpers for functions that return values through _<name> output variables.

F_NULL='<<null>>'

# Reset each named output to F_NULL.
f_prepare_args() {
  local out
  for out in "$@"; do
    printf -v "_${out}" '%s' "$F_NULL"
  done
}

# Error if any named output was not set by function fn.
f_end() {
  local fn="$1" out var
  shift
  for out in "$@"; do
    var="_${out}"
    if [[ -z "${!var+x}" || "${!var}" == "$F_NULL" ]]; then
      error "$fn: output '$var' was not initialized"
    fi
  done
}

# f_with_args <fn> <output>... [-- <arg>...]
# Prepare the outputs, call fn with the args, then check every output was set.
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

# Return 0 if space-separated list $1 contains word $2.
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
