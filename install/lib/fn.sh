# Helpers for functions that return named values: the function returns them with f_return, and its caller reads them
# with f_call, the way read sets the names it is given. They travel in _<name> variables local to each f_call, so they
# never leak as globals.

F_NULL='<<null>>'

# Return 0 if $1 is a variable name that doesn't start with an underscore, which f_call keeps for its own variables.
_f_is_name() {
  [[ "$1" == [a-zA-Z]* && "$1" != *[!a-zA-Z0-9_]* ]]
}

# Call fn with args and set the caller's variables from the values it returns with f_return: each var gets fn's value
# var, or with var=name, its value name. Errors unless fn returned each one. Values fn returns that the caller didn't
# ask for are dropped, and a nested call can't clobber an outer one's.
# Usage: f_call fn var[=name]... [-- args...]
f_call() {
  local __f_fn="$1" __f_spec __f_var __f_out __f_vars=() __f_outs=() __f_i
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    __f_spec="$1"
    shift
    __f_var="${__f_spec%%=*}"
    __f_out="${__f_spec#*=}"
    if ! _f_is_name "$__f_var" || ! _f_is_name "$__f_out"; then
      error "f_call $__f_fn: '$__f_spec' must be var or var=name, with names that don't start with an underscore"
    fi
    __f_vars+=("$__f_var")
    __f_outs+=("_$__f_out")
  done
  [[ $# -gt 0 ]] && shift
  [[ ${#__f_outs[@]} -gt 0 ]] || error "f_call $__f_fn: no outputs given"

  # f_return sets these, through bash's dynamic scoping, and only these.
  local "${__f_outs[@]}"
  for __f_out in "${__f_outs[@]}"; do
    printf -v "$__f_out" '%s' "$F_NULL"
  done
  "$__f_fn" "$@"
  __f_i=0
  while [[ $__f_i -lt ${#__f_outs[@]} ]]; do
    __f_out="${__f_outs[$__f_i]}"
    [[ "${!__f_out}" != "$F_NULL" ]] || error "$__f_fn: did not return '${__f_out#_}'"
    printf -v "${__f_vars[$__f_i]}" '%s' "${!__f_out}"
    __f_i=$((__f_i + 1))
  done
}

# Return each name=value to the nearest f_call that asked for name; one that no caller asked for is dropped, so a
# caller that needs none of fn's values calls fn directly. A bare name returns the caller's variable of that name, so
# `f_return os profile=default` is `f_return os="$os" profile=default`; it must be set. Call f_return again to replace
# a value. Each name=value splits at its first =, which a name can't contain, so the value can hold anything, = signs
# and newlines included, as long as it is quoted as one word. Values are strings: return a list as space-separated
# words, as the OS configs do. A value of exactly F_NULL reads as not returned.
# Usage: f_return name[=value]...
f_return() {
  local __f_arg __f_name __f_out
  for __f_arg in "$@"; do
    __f_name="${__f_arg%%=*}"
    _f_is_name "$__f_name" \
      || error "f_return: '$__f_arg' must be name or name=value, with a name that doesn't start with an underscore"
    if [[ "$__f_arg" != *=* ]]; then
      [[ -n "${!__f_name+x}" ]] || error "f_return: '$__f_name' is not set"
      __f_arg="$__f_name=${!__f_name}"
    fi
    __f_out="_$__f_name"
    [[ -z "${!__f_out+x}" ]] || printf -v "$__f_out" '%s' "${__f_arg#*=}"
  done
}

# Return 0 if space-separated list $1 contains word $2.
list_contains() {
  case " $1 " in
    *" $2 "*) return 0 ;;
    *)        return 1 ;;
  esac
}
