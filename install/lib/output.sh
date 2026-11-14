# Colored log helpers.

# Print a message, tagged [info].
# Usage: info <message>...
info()  { printf '\033[32m[info]\033[0m %s\n' "$*"; }

# Print a message on stderr, tagged [warn].
# Usage: warn <message>...
warn()  { printf '\033[33m[warn]\033[0m %s\n' "$*" >&2; }

# Print a message on stderr, tagged [error], and exit the script.
# Usage: error <message>...
error() { printf '\033[31m[error]\033[0m %s\n' "$*" >&2; exit 1; }
