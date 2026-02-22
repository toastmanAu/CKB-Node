#!/usr/bin/env bash
# =============================================================================
# CKB Node Setup Script for Orange Pi 3B (and compatible aarch64 boards)
# https://github.com/toastmanAu/CKB-Node
#
# Run this once after flashing a fresh image to:
#   - Install CKB (latest or specified version)
#   - Set up a systemd service (auto-start, auto-restart on failure)
#   - Disable WiFi power save (prevents random disconnects)
#   - Configure sudoers for passwordless operation
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/toastmanAu/CKB-Node/main/setup.sh | sudo bash
#   sudo ./setup.sh
#   sudo ./setup.sh 0.204.0    # install specific version
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▶${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✖${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}── $* ──────────────────────────────────────────${RESET}"; }

# ── Must run as root ──────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || error "Run with sudo: sudo $0 $*"

# ── Config ────────────────────────────────────────────────────────────────────
CKB_USER="${CKB_USER:-orangepi}"
CKB_HOME="${CKB_HOME:-/home/${CKB_USER}/ckb}"
SERVICE_NAME="ckb"
GITHUB_API="https://api.github.com/repos/nervosnetwork/ckb/releases/latest"
GITHUB_DL="https://github.com/nervosnetwork/ckb/releases/download"

# ── Architecture ─────────────────────────────────────────────────────────────
ARCH="$(uname -m)"
case "$ARCH" in
    aarch64) ARCH_SUFFIX="aarch64-unknown-linux-gnu" ;;
    x86_64)  ARCH_SUFFIX="x86_64-unknown-linux-gnu-portable" ;;
    *)       error "Unsupported architecture: $ARCH" ;;
esac

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "  ╔════════════════════════════════════╗"
echo "  ║      CKB Node Setup Script         ║"
echo "  ║  github.com/toastmanAu/CKB-Node    ║"
echo "  ╚════════════════════════════════════╝"
echo -e "${RESET}"
info "User: ${CKB_USER} | Home: ${CKB_HOME} | Arch: ${ARCH}"

# ── Version ───────────────────────────────────────────────────────────────────
header "Version"
if [[ -n "${1:-}" ]]; then
    VERSION="${1#v}"
    info "Using specified version: v${VERSION}"
else
    info "Fetching latest release from GitHub..."
    VERSION=$(curl -fsSL "$GITHUB_API" 2>/dev/null | grep -oP '"tag_name":\s*"v\K[^"]+' | head -1)
    [[ -n "$VERSION" ]] || error "Could not fetch latest version. Pass version as argument: $0 0.204.0"
    info "Latest: v${VERSION}"
fi

RELEASE_URL="${GITHUB_DL}/v${VERSION}/ckb_v${VERSION}_${ARCH_SUFFIX}.tar.gz"
info "Verifying release exists..."
curl --output /dev/null --silent --head --fail "$RELEASE_URL" \
    || error "Release v${VERSION} not found. Check https://github.com/nervosnetwork/ckb/releases"
success "Release v${VERSION} confirmed."

# ── Install CKB ───────────────────────────────────────────────────────────────
header "Installing CKB"
TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

info "Downloading..."
curl -L --progress-bar "$RELEASE_URL" -o "$TEMP_DIR/ckb.tar.gz"

info "Extracting..."
tar -xzf "$TEMP_DIR/ckb.tar.gz" -C "$TEMP_DIR"
EXTRACTED="$TEMP_DIR/ckb_v${VERSION}_${ARCH_SUFFIX}"
[[ -d "$EXTRACTED" ]] || error "Extraction failed — directory not found: $EXTRACTED"

mkdir -p "$CKB_HOME"
rsync -a \
    --exclude=data \
    --exclude=ckb.toml \
    --exclude=ckb-miner.toml \
    --exclude='*.sh' \
    --exclude='*.bak' \
    --delete \
    "$EXTRACTED/" "$CKB_HOME/"
chmod +x "$CKB_HOME/ckb"
chown -R "${CKB_USER}:${CKB_USER}" "$CKB_HOME"

# Init config if not present
if [[ ! -f "$CKB_HOME/ckb.toml" ]]; then
    info "Generating default config..."
    cd "$CKB_HOME" && sudo -u "$CKB_USER" ./ckb init --chain mainnet 2>/dev/null || true
fi

INSTALLED_VER="$("$CKB_HOME/ckb" --version | grep -oP '\d+\.\d+\.\d+' | head -1)"
success "CKB v${INSTALLED_VER} installed at ${CKB_HOME}"

# ── Systemd service ───────────────────────────────────────────────────────────
header "Systemd Service"
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Nervos CKB Node v${INSTALLED_VER}
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${CKB_HOME}
ExecStart=${CKB_HOME}/ckb run --indexer
ExecStop=/bin/kill -SIGTERM \$MAINPID
KillMode=mixed
TimeoutStopSec=60
Restart=on-failure
RestartSec=10
StandardOutput=append:${CKB_HOME}/ckb.log
StandardError=append:${CKB_HOME}/ckb.log

[Install]
WantedBy=multi-user.target
EOF

touch "${CKB_HOME}/ckb.log"
chown "${CKB_USER}:${CKB_USER}" "${CKB_HOME}/ckb.log"

systemctl daemon-reload
systemctl enable "$SERVICE_NAME"
systemctl start "$SERVICE_NAME"
sleep 3

if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Service '${SERVICE_NAME}' is active and enabled on boot."
else
    warn "Service started but may not be active. Check: journalctl -u ${SERVICE_NAME} -n 30"
fi

# ── WiFi power save ───────────────────────────────────────────────────────────
header "WiFi Power Save"
WLAN=$(iw dev 2>/dev/null | awk '/Interface/{print $2}' | head -1)
if [[ -n "$WLAN" ]]; then
    # Disable immediately
    iw dev "$WLAN" set power_save off 2>/dev/null && \
        info "Power save disabled on ${WLAN}" || \
        warn "Could not set power save (non-fatal)"

    # Persist via modprobe
    echo "options brcmfmac roamoff=1" > /etc/modprobe.d/brcmfmac.conf

    # udev rule for future interface bring-ups
    cat > /etc/udev/rules.d/70-wifi-powersave.rules << 'EOF'
ACTION=="add", SUBSYSTEM=="net", KERNEL=="wlan*", RUN+="/sbin/iw dev %k set power_save off"
EOF
    success "WiFi power save permanently disabled."

    # Disable via NetworkManager if present
    if command -v nmcli &>/dev/null; then
        CONN=$(nmcli -t -f NAME con show --active 2>/dev/null | head -1)
        if [[ -n "$CONN" ]]; then
            nmcli con modify "$CONN" wifi.powersave 2 2>/dev/null && \
                info "NetworkManager power save disabled for: ${CONN}" || true
        fi
    fi
else
    info "No wireless interface found — skipping WiFi config."
fi

# ── Sudoers ───────────────────────────────────────────────────────────────────
header "Sudoers"
SUDOERS_FILE="/etc/sudoers.d/${CKB_USER}"
if [[ ! -f "$SUDOERS_FILE" ]]; then
    echo "${CKB_USER} ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 440 "$SUDOERS_FILE"
    success "NOPASSWD sudo configured for ${CKB_USER}."
else
    info "Sudoers already configured — skipping."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  Setup complete!${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════════${RESET}"
echo ""
echo -e "  CKB version : ${BOLD}v${INSTALLED_VER}${RESET}"
echo -e "  Install dir : ${BOLD}${CKB_HOME}${RESET}"
echo -e "  Service     : ${BOLD}systemctl {start|stop|status} ${SERVICE_NAME}${RESET}"
echo -e "  Logs        : ${BOLD}journalctl -u ${SERVICE_NAME} -f${RESET}"
echo -e "  WiFi PS     : ${BOLD}disabled${RESET}"
echo ""
echo -e "  To update CKB later:"
echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/toastmanAu/CKB-Node/main/update_ckb.sh | sudo bash${RESET}"
echo ""
