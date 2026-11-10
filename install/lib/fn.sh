# Helpers for functions that return values through _<name> output variables.

F_NULL='<<null>>'

# Call fn with args and set the caller's variables from its outputs, the way read sets the names it is given: each
# var gets fn's output _var, or with var=_out, its output _out. Errors unless fn set each output. The outputs are local
# to this call, reset to F_NULL first, so they don't leak as globals, a value left over from an earlier call doesn't
# count, and a nested call can't clobber an outer one's. Variable names must not start with an underscore, which
# would let these locals shadow them, and output names must start with a single one.
# Usage: f_call fn var[=_out]... [-- args...]
f_call() {
  local __f_fn="$1" __f_spec __f_var __f_out __f_vars=() __f_outs=() __f_i
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    __f_spec="$1"
    shift
    if [[ "$__f_spec" == *=* ]]; then
      __f_var="${__f_spec%%=*}"
      __f_out="${__f_spec#*=}"
    else
      __f_var="$__f_spec"
      __f_out="_$__f_spec"
    fi
    [[ "$__f_var" == [a-zA-Z]* && "$__f_var" != *[!a-zA-Z0-9_]* ]] \
      || error "f_call $__f_fn: '$__f_var' must be a variable name that doesn't start with an underscore"
    [[ "$__f_out" == _[!_]* && "$__f_out" != *[!a-zA-Z0-9_]* ]] \
      || error "f_call $__f_fn: output '$__f_out' must start with a single underscore"
    __f_vars+=("$__f_var")
    __f_outs+=("$__f_out")
  done
  [[ $# -gt 0 ]] && shift
  [[ ${#__f_outs[@]} -gt 0 ]] || error "f_call $__f_fn: no outputs given"

  local "${__f_outs[@]}"
  for __f_out in "${__f_outs[@]}"; do
    printf -v "$__f_out" '%s' "$F_NULL"
  done
  "$__f_fn" "$@"
  __f_i=0
  while [[ $__f_i -lt ${#__f_outs[@]} ]]; do
    __f_out="${__f_outs[$__f_i]}"
    [[ "${!__f_out}" != "$F_NULL" ]] || error "$__f_fn: output '$__f_out' was not initialized"
    printf -v "${__f_vars[$__f_i]}" '%s' "${!__f_out}"
    __f_i=$((__f_i + 1))
  done
}

# Return 0 if space-separated list $1 contains word $2.
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
