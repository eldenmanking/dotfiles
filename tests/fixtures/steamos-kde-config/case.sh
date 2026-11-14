# --desktop_settings (KDE) on a home whose ~/.config/kcminputrc and ~/.config/kxkbrc Plasma already wrote: the keys in
# home/.config/kcminputrc (keyboard repeat) and home/.config/kxkbrc (no XKB options) are merged in, and the others are
# left alone. ~/.config/powerdevilrc is new, so it gets just the lid action.
IMAGE=steamos
ARGS="--variant steamos --desktop_settings"
FILES=".config/kcminputrc .config/kxkbrc .config/powerdevilrc"
