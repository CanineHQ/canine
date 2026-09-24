#!/bin/bash
# Turns a stock Ubuntu 24.04 cloud image into the agent computer golden image. It runs once per cluster in a
# throwaway builder VM (AgentComputers::BuildImageJob), and every agent computer's disk is cloned from the result.
# The builder also drops /root/computer_server.tar.gz (resources/agent_computer/computer_server). Changing either
# changes the image version, so clusters rebuild on the next provision.
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

ARCH="$(dpkg --print-architecture)"
DESKTOP_USER=computer

SELKIES_VERSION=2.0.0
declare -A SELKIES_SHA256=(
  [amd64]=bbaa4d71012b9374a753b7dfddc1da07e31f34b04277fe4fb3d045f18fd88391
  [arm64]=3900f3ba805898c495829629092553cc1cf4d5a864ffc4056f57d21646ad45e4
)

# Google only ships Chrome for Linux on amd64
[ "$ARCH" = amd64 ] || { echo "Agent computers need amd64 nodes (Google Chrome has no arm64 Linux build)"; exit 1; }

# --- Desktop, VM plumbing and everyday tools ---------------------------------------------------------------
apt-get update
apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal xfce4-notifyd xfce4-screenshooter thunar mousepad \
  dbus-x11 at-spi2-core libatk-adaptor xdg-utils xclip xdotool xinput wmctrl \
  xvfb xauth x11-xserver-utils pulseaudio \
  xfonts-base fonts-dejavu-core fonts-noto-core fonts-noto-color-emoji elementary-xfce-icon-theme \
  qemu-guest-agent chrony \
  python3-venv python3-gi gir1.2-atspi-2.0 libx11-dev libxi-dev \
  sudo curl ca-certificates gnupg git jq unzip less htop neovim micro build-essential

# --- Google Chrome, shared by the person and agents --------------------------------------------------------------
install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" \
  > /etc/apt/sources.list.d/google-chrome.list
apt-get update
apt-get install -y google-chrome-stable

# Always expose CDP on localhost so the computer server can drive the same window the person sees (Chrome only
# honours --remote-debugging-port with a non-default profile), and put web content in the accessibility tree.
cat > /usr/local/bin/google-chrome <<'EOF'
#!/bin/sh
exec /usr/bin/google-chrome-stable --user-data-dir="$HOME/.config/google-chrome-agent" \
  --remote-debugging-port=9222 --remote-debugging-address=127.0.0.1 --force-renderer-accessibility \
  --no-first-run --no-default-browser-check "$@"
EOF
chmod 755 /usr/local/bin/google-chrome
# /usr/local/share/applications shadows the package's launcher, so menus and "open link" use the wrapper too
install -d /usr/local/share/applications
sed 's#^Exec=/usr/bin/google-chrome-stable#Exec=/usr/local/bin/google-chrome#' /usr/share/applications/google-chrome.desktop \
  > /usr/local/share/applications/google-chrome.desktop
update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/local/bin/google-chrome 300
cat > /etc/xdg/mimeapps.list <<'EOF'
[Default Applications]
text/html=google-chrome.desktop
x-scheme-handler/http=google-chrome.desktop
x-scheme-handler/https=google-chrome.desktop
EOF
printf 'WebBrowser=google-chrome\n' > /etc/xdg/xfce4/helpers.rc

# --- The desktop user -------------------------------------------------------------------------------------
# Each agent computer is its own VM, so passwordless sudo is fine
useradd -m -s /bin/bash -G sudo,audio,video "$DESKTOP_USER"
echo "$DESKTOP_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$DESKTOP_USER"
chmod 0440 "/etc/sudoers.d/90-$DESKTOP_USER"

# --- Selkies: streams the desktop to the browser --------------------------------------------------------------
curl -fsSL -o /tmp/selkies.deb \
  "https://github.com/selkies-project/selkies/releases/download/${SELKIES_VERSION}/selkies-${SELKIES_VERSION}-ubuntu24.04-${ARCH}.deb"
echo "${SELKIES_SHA256[$ARCH]}  /tmp/selkies.deb" | sha256sum -c -
apt-get install -y /tmp/selkies.deb
rm /tmp/selkies.deb

# selkies-session starts its own Xvfb display and PulseAudio (its .deb depends on neither, so they're installed
# above), then XFCE. --public listens on the VM's network card (Canine reaches it through kubectl port-forward;
# a NetworkPolicy blocks everything else). The accessibility variables make GTK/Qt apps publish their UI to AT-SPI.
cat > /etc/systemd/system/selkies.service <<EOF
[Unit]
Description=Selkies desktop session
After=network-online.target systemd-user-sessions.service
Wants=network-online.target

[Service]
User=${DESKTOP_USER}
PAMName=login
WorkingDirectory=/home/${DESKTOP_USER}
Environment=SELKIES_USE_CSS_SCALING=true
Environment=GTK_MODULES=gail:atk-bridge
Environment=ACCESSIBILITY_ENABLED=1
Environment=QT_ACCESSIBILITY=1
ExecStart=/usr/bin/selkies-session --session=xfce --public --port=8080 --enable-basic-auth=false --enable-https=false
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF
systemctl enable selkies.service

# --- Computer server: the agent control API on :8000 ----------------------------------------------------------
# System Python so the AT-SPI bindings (python3-gi) are visible inside the venv
install -d /opt/computer-server
tar -xzf /root/computer_server.tar.gz -C /opt/computer-server
gcc -O2 -o /opt/computer-server/input-watch /opt/computer-server/input_watch.c -lX11 -lXi
python3 -m venv --system-site-packages /opt/computer-server/venv
/opt/computer-server/venv/bin/pip install --no-cache-dir -r /opt/computer-server/requirements.txt

cat > /opt/computer-server/start.sh <<'EOF'
#!/bin/sh
mkdir -p "$HOME/.cache"
cd /opt/computer-server
exec /opt/computer-server/venv/bin/python -m computer_server --host 0.0.0.0 --port 8000 >> "$HOME/.cache/computer-server.log" 2>&1
EOF
chmod 755 /opt/computer-server/start.sh

# Autostarted inside the XFCE session, so it inherits Selkies' DISPLAY/XAUTHORITY and the session's AT-SPI bus
cat > /etc/xdg/autostart/computer-server.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Computer server
Exec=/opt/computer-server/start.sh
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

# --- Slim down and reset per-machine identity so every clone boots as a new machine ------------------------------
apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /root/computer_server.tar.gz
cloud-init clean --logs --machine-id
