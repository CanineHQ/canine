#!/bin/bash
# Turns a fresh Omarchy install into an agent computer: streams the Hyprland session to the browser with Selkies.
# AgentComputers::ProvisionJob runs it over SSH as the desktop user once the unattended install has finished, with
# SETUP_PASSWORD (the generated password, for sudo until it's removed below), DESKTOP_PORT, COMPUTER_USE_PORT,
# SELKIES_PACKAGE_URL and SELKIES_PACKAGE_SHA256 set. Safe to run again.
set -euo pipefail
: "${SETUP_PASSWORD:?}" "${DESKTOP_PORT:?}" "${COMPUTER_USE_PORT:?}" "${SELKIES_PACKAGE_URL:?}" "${SELKIES_PACKAGE_SHA256:?}"
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

# --- Computer use: lets agents see and drive the desktop ------------------------------------------------------------
# The server is a Python package (resources/agent_computer/computer_use), copied to ~/.local/share/canine/computer_use
# before this ran. It goes in its own venv; --system-site-packages lets it use Omarchy's PyGObject for AT-SPI.
python3 -m venv --system-site-packages ~/.local/share/canine/venv
~/.local/share/canine/venv/bin/pip install --quiet --disable-pip-version-check ~/.local/share/canine/computer_use

# It clicks and presses keys through a virtual input device, which the desktop user (in wheel) may create.
echo uinput > /tmp/canine-uinput.conf
as_root install -m 644 /tmp/canine-uinput.conf /etc/modules-load.d/canine-uinput.conf
echo 'KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", GROUP="wheel", MODE="0660"' > /tmp/60-canine-uinput.rules
as_root install -m 644 /tmp/60-canine-uinput.rules /etc/udev/rules.d/60-canine-uinput.rules
rm /tmp/canine-uinput.conf /tmp/60-canine-uinput.rules
as_root modprobe uinput

# Apps only publish their accessibility tree (what agents read and press by name) when asked: GTK through this
# setting, Qt through QT_ACCESSIBILITY, Chromium through a flag
gsettings set org.gnome.desktop.interface toolkit-accessibility true
mkdir -p ~/.config/environment.d
echo QT_ACCESSIBILITY=1 > ~/.config/environment.d/60-canine-accessibility.conf
grep -qx -- --force-renderer-accessibility ~/.config/chromium-flags.conf 2>/dev/null ||
  echo --force-renderer-accessibility >> ~/.config/chromium-flags.conf

# browse (browser-use) drives Chromium over the DevTools protocol on a port that listens only inside the VM. The
# open-source Chromium Arch ships allows this on the normal profile (Google Chrome-branded builds would not: they
# need a non-default --user-data-dir). Restart Chromium after adding the flag for it to take effect.
grep -qx -- --remote-debugging-port=9222 ~/.config/chromium-flags.conf 2>/dev/null ||
  echo --remote-debugging-port=9222 >> ~/.config/chromium-flags.conf

cat > ~/.config/systemd/user/canine-computer-use.service <<UNIT
[Unit]
Description=Canine computer-use server
After=graphical-session.target
PartOf=graphical-session.target

[Service]
ExecStart=%h/.local/share/canine/venv/bin/canine-computer-use --port ${COMPUTER_USE_PORT}
Restart=always
RestartSec=2
# Restarting the server (a deploy) mustn't take the terminal sessions it started with it: tmux runs in this unit
KillMode=process

[Install]
WantedBy=graphical-session.target
UNIT
ln -sf ../canine-computer-use.service ~/.config/systemd/user/graphical-session.target.wants/canine-computer-use.service
as_root ufw allow "${COMPUTER_USE_PORT}/tcp" comment "Computer use (Canine)" >/dev/null

# The computer-use tools for agent harnesses running on this computer (scheduled tasks), as a standard mcpServers
# config; AgentComputerTask's commands point at it with $CANINE_MCP_CONFIG
mkdir -p ~/.config/canine
cat > ~/.config/canine/mcp.json <<JSON
{"mcpServers": {"computer": {"command": "$HOME/.local/share/canine/venv/bin/canine-computer-use", "args": ["mcp"]}}}
JSON

# Omarchy's first-run notifications ("Update System", "Learn Keybindings") stay until dismissed, covering the top right
# of every app, including buttons agents need. Dismiss them through Omarchy's own post-boot hook, once its first-run
# setup (which sends them) has finished.
mkdir -p ~/.config/omarchy/hooks/post-boot.d
cat > ~/.config/omarchy/hooks/post-boot.d/canine-dismiss-welcome <<'HOOK'
#!/bin/bash
# Canine: first-run notifications cover the top right of the streamed desktop
for _ in $(seq 60); do [ -e ~/.local/state/omarchy/done/first-run-user ] && break; sleep 2; done
sleep 5
omarchy-shell -q notifications dismissAll
HOOK
chmod +x ~/.config/omarchy/hooks/post-boot.d/canine-dismiss-welcome

# --- Guest agent: let KubeVirt (and so the UI) see inside the VM -----------------------------------------------------
# qemu-guest-agent talks to KubeVirt over the virtio-serial channel KubeVirt adds by default. Without it KubeVirt
# reports AgentConnected=false and can't fill in the guest OS or the filesystem usage, so the computer's Live Stats
# show a blank Operating System and Disk and a "Not connected" guest agent. Installing and enabling it fixes all three.
if ! command -v qemu-ga >/dev/null; then
  as_root pacman -Sy --noconfirm --needed qemu-guest-agent
fi
as_root systemctl enable --now qemu-guest-agent.service

# Docker is installed but only root can use it; let the desktop user (and so agents' commands) run containers
getent group docker >/dev/null && as_root usermod -aG docker "$USER"

# --- Memory: lose a tab, not the browser ----------------------------------------------------------------------------
# systemd-oomd kills a whole app (every Chromium window at once) when the desktop's app slice stalls on memory or swap
# fills up (/usr/lib/systemd/user/app.slice.d/10-oomd.conf). Turned off for apps, the kernel's own OOM killer acts
# instead when memory really runs out, and it takes Chromium's tab processes first (they're marked to go first): a tab
# crashes, the browser and its windows stay. Memory Saver frees tabs that haven't been used for a while.
sudo mkdir -p /etc/systemd/user/app.slice.d /etc/chromium/policies/managed
sudo tee /etc/systemd/user/app.slice.d/90-canine-no-oomd.conf >/dev/null <<'CONF'
[Slice]
ManagedOOMMemoryPressure=auto
ManagedOOMSwap=auto
CONF
systemctl --user daemon-reload
sudo tee /etc/chromium/policies/managed/canine.json >/dev/null <<'JSON'
{"HighEfficiencyModeEnabled": true, "MemorySaverModeSavings": 1}
JSON

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
# Idle locking off. Omarchy's "stay awake" flag does this, but omarchy-update deletes it when it finishes, so also set
# the idle timeouts as long as Omarchy's timers allow (~23 days; 0 would mean "immediately").
mkdir -p ~/.local/state/omarchy/indicators
touch ~/.local/state/omarchy/indicators/stay-awake
mkdir -p ~/.config/omarchy
[ -f ~/.config/omarchy/shell.json ] || cp /usr/share/omarchy/config/omarchy/shell.json ~/.config/omarchy/shell.json
python3 - <<'PY'
import json, os
path = os.path.expanduser("~/.config/omarchy/shell.json")
config = json.load(open(path))
config["idle"] = {"screensaver": 2000000, "lock": 2000000}
json.dump(config, open(path, "w"), indent=2)
PY
sudo passwd -d "$USER" >/dev/null

# Restarting the display manager applies the autologin, which starts Hyprland and with it Selkies
sudo systemctl restart sddm
echo "OMARCHY_SETUP_OK"
