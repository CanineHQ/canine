#!/bin/bash
# Turns a fresh Omarchy install into an agent computer: streams the Hyprland session to the browser with Selkies.
# AgentComputers::ProvisionJob runs it over SSH as the desktop user once the unattended install has finished, with
# SETUP_PASSWORD (the generated password, for sudo until it's removed below), DESKTOP_PORT, SELKIES_PACKAGE_URL and SELKIES_PACKAGE_SHA256 set. Safe to run again.
set -euo pipefail
: "${SETUP_PASSWORD:?}" "${DESKTOP_PORT:?}" "${SELKIES_PACKAGE_URL:?}" "${SELKIES_PACKAGE_SHA256:?}"
as_root() { printf '%s\n' "$SETUP_PASSWORD" | sudo -S -p '' "$@"; }

# --- Selkies ---------------------------------------------------------------------------------------------------------
if ! command -v selkies >/dev/null; then
  package=/tmp/selkies.pkg.tar.zst
  curl -fsSL --retry 3 -o "$package" "$SELKIES_PACKAGE_URL"
  echo "$SELKIES_PACKAGE_SHA256  $package" | sha256sum -c -
  as_root pacman -U --noconfirm --needed "$package"
  rm -f "$package"
fi

# Log straight into the Hyprland session (via uwsm), so there's always a desktop for Selkies to stream
printf '[Autologin]\nUser=%s\nSession=hyprland-uwsm.desktop\nRelogin=true\n' "$USER" > /tmp/50-autologin.conf
as_root install -m 644 /tmp/50-autologin.conf /etc/sddm.conf.d/50-autologin.conf
rm /tmp/50-autologin.conf

# Selkies attaches to the session's own compositor; uwsm exports WAYLAND_DISPLAY to user services. The resolution is
# pinned on both sides, or Selkies' resize requests and Hyprland's monitor changes chase each other.
mkdir -p ~/.config/systemd/user/graphical-session.target.wants
cat > ~/.config/systemd/user/selkies.service <<UNIT
[Unit]
Description=Selkies stream of the Hyprland session
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Environment=SELKIES_WAYLAND=true
Environment=SELKIES_USE_CSS_SCALING=true
# On a Mac, Selkies sends Cmd+key as Ctrl+key by default; Omarchy's shortcuts are Super+key, so send Cmd as Super (locked,
# so a value the browser remembered from before can't override it)
Environment=SELKIES_MAC_CMD_AS_CTRL=false|locked
Environment=SELKIES_MANUAL_WIDTH=1920
Environment=SELKIES_MANUAL_HEIGHT=1080
ExecStart=/bin/sh -c 'exec /usr/bin/selkies --public --port=${DESKTOP_PORT} --enable-basic-auth=false --enable-https=false --wayland-host-display="\$WAYLAND_DISPLAY"'
Restart=always
RestartSec=2

[Install]
WantedBy=graphical-session.target
UNIT
ln -sf ../selkies.service ~/.config/systemd/user/graphical-session.target.wants/selkies.service

# Omarchy's firewall allows nothing by default. Only Canine reaches this port (kubectl port-forward), and a
# NetworkPolicy blocks everything else in the cluster.
as_root ufw allow "${DESKTOP_PORT}/tcp" comment "Selkies (Canine)" >/dev/null

# --- Hyprland tuned for streaming --------------------------------------------------------------------------------------
# Fixed 1080p at 1.25 scale: larger text, and one resolution for Selkies to encode
sed -i 's/^hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })/hl.monitor({ output = "", mode = "1920x1080@60", position = "auto", scale = 1.25 })/' \
  ~/.config/hypr/monitors.lua
grep -q 'mode = "1920x1080@60"' ~/.config/hypr/monitors.lua || { echo "monitors.lua has an unexpected layout" >&2; exit 1; }

if ! grep -q "Canine: streamed through Selkies" ~/.config/hypr/looknfeel.lua; then
  cat >> ~/.config/hypr/looknfeel.lua <<'LUA'

-- Canine: streamed through Selkies. The browser draws its own (instant) pointer, so don't draw a second one into the
-- video. There's no GPU in the VM, so every frame is drawn on the CPU: skip the costly effects.
hl.config({
  cursor = { invisible = true },
  animations = { enabled = false },
  decoration = {
    blur = { enabled = false },
    shadow = { enabled = false },
  },
})
LUA
fi

# Omarchy's screensaver hides the cursor while it runs and turns it back on when it exits, undoing the setting above
# (a second, lagging pointer in the stream). Nobody watches an idle stream, so turn it off; that also saves CPU.
mkdir -p ~/.local/state/omarchy/toggles
touch ~/.local/state/omarchy/toggles/screensaver-off

# --- No desktop password: Canine already decides who can reach this desktop ---------------------------------------
# sudo and graphical admin prompts stop asking, idle locking is off, and the account's password is deleted. Omarchy's
# lock screen allows empty passwords (nullok), so if someone locks it by hand, typing anything and Enter unlocks it.
# (The installer requires a password, so Canine generated one; it's only needed until this point.)
echo "$USER ALL=(ALL) NOPASSWD: ALL" > /tmp/90-canine-nopasswd
as_root visudo -cqf /tmp/90-canine-nopasswd
as_root install -m 440 /tmp/90-canine-nopasswd /etc/sudoers.d/90-canine-nopasswd
rm /tmp/90-canine-nopasswd
cat > /tmp/49-canine-nopasswd.rules <<'RULES'
// Canine: the desktop is only reachable through Canine's authenticated proxy, so admin prompts don't ask for a password
polkit.addRule(function(action, subject) {
  if (subject.isInGroup("wheel")) return polkit.Result.YES;
});
RULES
sudo install -m 644 /tmp/49-canine-nopasswd.rules /etc/polkit-1/rules.d/49-canine-nopasswd.rules
rm /tmp/49-canine-nopasswd.rules
mkdir -p ~/.local/state/omarchy/indicators
touch ~/.local/state/omarchy/indicators/stay-awake
sudo passwd -d "$USER" >/dev/null

# Restarting the display manager applies the autologin, which starts Hyprland and with it Selkies
sudo systemctl restart sddm
echo "OMARCHY_SETUP_OK"
