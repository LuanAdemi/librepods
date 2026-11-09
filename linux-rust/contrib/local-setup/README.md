# Local setup: LibrePods on a desktop with a USB Bluetooth adapter

This is how LibrePods is installed and run on my machine (Fedora / KDE Plasma, PipeWire + WirePlumber, AirPods Pro, USB Bluetooth dongle). Everything needed to set it up again from scratch is in this folder.

## Where things are

| What | Where |
|---|---|
| Source code (my fork) | <https://github.com/borislisandro/librepods>, branch `linux-rust/robust-audio` (in `linux-rust/`) |
| Upstream pull request with the same code | <https://github.com/librepods-org/librepods/pull/888> (branch `linux-rust/robust-audio-upstream`) |
| Full history and audit notes | <https://github.com/borislisandro/librepods/pull/1> |
| Installed binary | `~/.local/bin/librepods` |
| App settings | `~/.config/librepods/app_settings.json` (editable in the app's Settings tab) |
| Paired devices and keys | `~/.local/share/librepods/devices.json` |
| Logs | `journalctl --user -u librepods.service -f` |

## Set up again from scratch

```sh
git clone https://github.com/borislisandro/librepods.git
cd librepods && git switch linux-rust/robust-audio
cd linux-rust/contrib/local-setup
./install.sh                 # builds, installs and enables everything
# or: ./install.sh AA:BB:CC:DD:EE:FF   to give the AirPods' address explicitly
```

Build requirements (Fedora): `rust`, `cargo`, `pkgconf`, `dbus-devel`, `pulseaudio-libs-devel`, `libavcodec-free-devel`.

### After code changes, rebuild and reinstall

```sh
cd ~/Documents/Github/librepods/linux-rust/contrib/local-setup && ./install.sh
```

## What each file does

| File | Installed to | Purpose |
|---|---|---|
| `librepods.service` | `~/.config/systemd/user/` | Runs LibrePods only while a Bluetooth adapter is plugged in: starts when the dongle appears (udev starts `bluetooth.target`), stops when it's removed. Without it, LibrePods crashed at every boot without the dongle. |
| `librepods-wait-adapter` | `~/.local/bin/` | Run before LibrePods starts: waits until BlueZ has registered and powered the adapter (on re-plug `bluetoothd` is already running, but the new adapter isn't ready yet). |
| `51-bluetooth-stay-a2dp.conf` | `~/.config/wireplumber/wireplumber.conf.d/` | Keeps the AirPods in high-quality A2DP (AAC) instead of switching to headset mode when an app opens a mic. LibrePods' hi-res mic replaces headset mode for calls. |
| `install.sh` | — | Does all of the above, backs up anything it replaces, and disables the old XDG autostart entry (`~/.config/autostart/librepods.desktop` gets `Hidden=true`). |

## How it behaves

| Situation | What happens |
|---|---|
| Dongle plugged in | LibrePods starts in the tray within a few seconds |
| Dongle unplugged | LibrePods stops |
| Both buds in | Sound and the microphone ("&lt;AirPods name&gt; Microphone") work like a wired headset |
| One bud out | Playback continues, and the mic keeps working |
| Both buds out | Media pauses at once; after 4 s sound and mic move to other devices, and come back when a bud goes in |
| Talking to an app (dictation, calls) | No device switching. One short dip about 60 s after the mic is last used (that resets the AirPods to both-bud playback) |

## Useful commands

```sh
systemctl --user status librepods.service      # running?
journalctl --user -u librepods.service -f       # live log
systemctl --user restart librepods.service      # restart
ls ~/.local/bin/librepods.bak-*                 # previous binaries (install.sh backups)
```

To go back to a previous binary:

```sh
cp ~/.local/bin/librepods.bak-<date> ~/.local/bin/librepods
systemctl --user restart librepods.service
```
