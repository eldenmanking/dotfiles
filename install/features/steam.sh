# Feature: Steam client settings (steamos game mode).

STEAM_USERDATA="$HOME/.local/share/Steam/userdata"

# Settings as "key|value" in each Steam user's config/localconfig.vdf (the hotkeys are in its "Gamescope" section).
# Hotkeys are the modifiers and the key separated by tabs, as Steam writes them.
STEAM_SETTINGS=(
  "GuideKeyboardHotkey|Win	KEY_TAB"         # main menu (Steam button)
  "QAMKeyboardHotkey|Shift	Win	KEY_TAB"     # quick access menu (... button)
)

# Replace the STEAM_SETTINGS values in each Steam user's localconfig.vdf (steam_set_vdf, install/lib/steam.sh). Only
# keys Steam already wrote are replaced, so a missing one must be set once in Steam first. Steam rewrites the file from
# memory when it exits, so this only edits it while Steam isn't running; the settings apply the next time Steam starts.
#
# @machine any
# @os steamos
# @gui any
feature_steam() {
  local file found=false changed=false written missing
  for file in "$STEAM_USERDATA"/*/config/localconfig.vdf; do
    [[ -f "$file" ]] || continue
    found=true
    f_call steam_set_vdf written=changed missing -- "$file" "${STEAM_SETTINGS[@]}"
    [[ -z "$missing" ]] || warn "$file has no $missing; set it once in Steam (Settings > In Game), then rerun with --steam."
    [[ -z "$written" ]] || changed=true
  done

  if ! $found; then
    warn "No Steam user config under $STEAM_USERDATA; sign in to Steam once, then rerun with --steam."
  elif $changed; then
    info "Steam settings updated; they apply the next time Steam starts."
  fi
}
