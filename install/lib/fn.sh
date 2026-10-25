# Helpers for functions that return values through _<name> output variables.

F_NULL='<<null>>'

# Reset each named output to F_NULL.
f_prepare_args() {
  local out
  for out in "$@"; do
    printf -v "$out" '%s' "$F_NULL"
  done
}

# Error if any named output was not set by function fn.
f_end() {
  local fn="$1" out
  shift
  for out in "$@"; do
    if [[ -z "${!out+x}" || "${!out}" == "$F_NULL" ]]; then
      error "$fn: output '$out' was not initialized"
    fi
  done
}

# Call fn with args, then error unless it set each named output. Outputs are reset to F_NULL first, so a value left
# over from an earlier call doesn't count. Each must start with a single underscore.
# Usage: f_write_args fn _out1 [_out2...] [-- args...]
f_write_args() {
  local fn="$1" outs=()
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    [[ "$1" == _[!_]* ]] || error "f_write_args $fn: output '$1' must start with a single underscore"
    outs+=("$1")
    shift
  done
  [[ $# -gt 0 ]] && shift
  [[ ${#outs[@]} -gt 0 ]] || error "f_write_args $fn: no outputs given"
  f_prepare_args "${outs[@]}"
  "$fn" "$@"
  f_end "$fn" "${outs[@]}"
}

# Return 0 if space-separated list $1 contains word $2.
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
