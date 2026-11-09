#!/bin/sh
# Build LibrePods and set it up for the current user:
#   - binary            -> ~/.local/bin/librepods            (old one backed up)
#   - adapter wait step -> ~/.local/bin/librepods-wait-adapter
#   - systemd user unit -> ~/.config/systemd/user/librepods.service (enabled)
#   - XDG autostart entry, if any, is disabled (the unit replaces it)
#   - WirePlumber "stay in A2DP" config for your AirPods (optional)
#
# Usage: ./install.sh [--no-build] [AIRPODS_MAC]
#   --no-build    install the existing target/release/librepods
#   AIRPODS_MAC   e.g. AA:BB:CC:DD:EE:FF; if omitted, a paired device whose name
#                 contains "AirPods" is used, or the WirePlumber step is skipped.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
crate=$(cd "$here/../.." && pwd)          # linux-rust/
bin="$HOME/.local/bin"
units="$HOME/.config/systemd/user"
wpconf="$HOME/.config/wireplumber/wireplumber.conf.d"
stamp=$(date +%Y%m%d-%H%M%S)

build=1
mac=""
for arg in "$@"; do
    case "$arg" in
        --no-build) build=0 ;;
        *:*:*:*:*:*) mac=$arg ;;
        *) echo "unknown argument: $arg" >&2; exit 2 ;;
    esac
done

# 1. Build (low priority, 2 jobs: keeps the desktop and games responsive).
if [ "$build" = 1 ]; then
    echo "==> Building (cargo build --release)"
    (cd "$crate" && nice -n 19 ionice -c 3 cargo build --release -j 2)
fi
[ -x "$crate/target/release/librepods" ] || { echo "no binary at $crate/target/release/librepods" >&2; exit 1; }

# 2. Binary and wait script.
mkdir -p "$bin"
if [ -e "$bin/librepods" ]; then
    cp "$bin/librepods" "$bin/librepods.bak-$stamp"
    echo "==> Backed up old binary to $bin/librepods.bak-$stamp"
fi
install -m755 "$crate/target/release/librepods" "$bin/librepods"
install -m755 "$here/librepods-wait-adapter" "$bin/librepods-wait-adapter"
echo "==> Installed $bin/librepods and $bin/librepods-wait-adapter"

# 3. systemd user unit (starts with the Bluetooth adapter, stops when it's gone).
mkdir -p "$units"
install -m644 "$here/librepods.service" "$units/librepods.service"
systemctl --user daemon-reload
systemctl --user enable librepods.service >/dev/null
echo "==> Installed and enabled librepods.service"

# 4. Disable an XDG autostart entry: the unit replaces it, and autostart would
#    start LibrePods at login even without an adapter.
for f in "$HOME/.config/autostart/librepods.desktop" \
         "$HOME/.config/autostart/me.kavishdevar.librepods.desktop"; do
    if [ -f "$f" ] && ! grep -q '^Hidden=true' "$f"; then
        echo "Hidden=true" >> "$f"
        echo "==> Disabled autostart entry $f"
    fi
done

# 5. WirePlumber config (optional): keep the AirPods in A2DP.
if [ -z "$mac" ] && command -v bluetoothctl >/dev/null; then
    mac=$(bluetoothctl devices 2>/dev/null | awk '/AirPods/ {print $2; exit}')
fi
if [ -n "$mac" ]; then
    mkdir -p "$wpconf"
    target="$wpconf/51-bluetooth-stay-a2dp.conf"
    [ -e "$target" ] && cp "$target" "$target.bak-$stamp"
    sed "s/AIRPODS_MAC/$(echo "$mac" | tr ':' '_')/" "$here/51-bluetooth-stay-a2dp.conf" > "$target"
    echo "==> Installed $target for $mac (restart WirePlumber to apply:"
    echo "    systemctl --user restart wireplumber)"
else
    echo "==> Skipped WirePlumber config (no AirPods found; pass the MAC as an argument)"
fi

# 6. (Re)start now if an adapter is present.
if ls /sys/class/bluetooth/hci* >/dev/null 2>&1; then
    systemctl --user restart librepods.service
    echo "==> LibrePods (re)started"
else
    echo "==> No Bluetooth adapter right now; LibrePods starts when one is plugged in"
fi
