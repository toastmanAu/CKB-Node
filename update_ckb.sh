#!/usr/bin/env bash
# =============================================================================
# CKB Node Update Script
# https://github.com/toastmanAu/CKB-Node
#
# Safely updates a running CKB node to any release version.
# - Auto-detects latest release if no version given
# - Stops/starts the node service gracefully
# - Backs up current binary before overwriting
# - Preserves data/, ckb.toml, and local scripts
# - Works on aarch64 (Orange Pi 3B) and x86_64
# =============================================================================

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}▶${RESET} $*"; }
success() { echo -e "${GREEN}✔${RESET} $*"; }
warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
error()   { echo -e "${RED}✖${RESET} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}$*${RESET}"; }

# ── Config ────────────────────────────────────────────────────────────────────
CKB_HOME="${CKB_HOME:-/home/orangepi/ckb}"
GITHUB_API="https://api.github.com/repos/nervosnetwork/ckb/releases/latest"
GITHUB_DL="https://github.com/nervosnetwork/ckb/releases/download"
SERVICE_NAME="ckb"   # systemd service name — adjust if yours differs

# ── Architecture ─────────────────────────────────────────────────────────────
ARCH="$(uname -m)"
case "$ARCH" in
    aarch64) ARCH_SUFFIX="aarch64-unknown-linux-gnu" ;;
    x86_64)  ARCH_SUFFIX="x86_64-unknown-linux-gnu-portable" ;;
    *)       error "Unsupported architecture: $ARCH" ;;
esac

# ── Temp dir + cleanup ────────────────────────────────────────────────────────
TEMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# ── Helpers ───────────────────────────────────────────────────────────────────
get_current_version() {
    if [[ -x "$CKB_HOME/ckb" ]]; then
        "$CKB_HOME/ckb" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown"
    else
        echo "not installed"
    fi
}

get_latest_version() {
    curl -fsSL "$GITHUB_API" 2>/dev/null \
        | grep -oP '"tag_name":\s*"v\K[^"]+' \
        | head -1
}

service_is_active() {
    systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null
}

# ── Banner ────────────────────────────────────────────────────────────────────
echo -e "${BOLD}${CYAN}"
echo "  ╔═══════════════════════════════╗"
echo "  ║    CKB Node Update Script     ║"
echo "  ║  github.com/toastmanAu/CKB-Node ║"
echo "  ╚═══════════════════════════════╝"
echo -e "${RESET}"

# ── Current state ─────────────────────────────────────────────────────────────
header "Current installation"
CURRENT_VERSION="$(get_current_version)"
info "Install path : $CKB_HOME"
info "Architecture : $ARCH ($ARCH_SUFFIX)"
info "Installed    : v${CURRENT_VERSION}"

# ── Version selection ─────────────────────────────────────────────────────────
header "Version selection"
info "Fetching latest release from GitHub..."
LATEST_VERSION="$(get_latest_version)" || true

if [[ -n "${1:-}" ]]; then
    # Version passed as argument
    VERSION="$1"
    info "Using provided version: v${VERSION}"
elif [[ -t 0 ]]; then
    # Interactive
    if [[ -n "$LATEST_VERSION" ]]; then
        echo -e "  Latest available: ${GREEN}v${LATEST_VERSION}${RESET}"
    else
        warn "Could not fetch latest version from GitHub."
    fi
    echo -n -e "  Enter version to install [${LATEST_VERSION:-?}]: "
    read -r VERSION
    VERSION="${VERSION:-$LATEST_VERSION}"
else
    # Non-interactive, no arg — use latest
    [[ -n "$LATEST_VERSION" ]] || error "Could not determine latest version. Pass version as argument: $0 0.204.0"
    VERSION="$LATEST_VERSION"
    info "Non-interactive mode — installing latest: v${VERSION}"
fi

# Strip leading 'v' if user typed it
VERSION="${VERSION#v}"
[[ -n "$VERSION" ]] || error "No version specified."

if [[ "$VERSION" == "$CURRENT_VERSION" ]]; then
    warn "v${VERSION} is already installed. Re-installing anyway..."
fi

# ── Verify release exists ─────────────────────────────────────────────────────
header "Verifying release"
RELEASE_URL="${GITHUB_DL}/v${VERSION}/ckb_v${VERSION}_${ARCH_SUFFIX}.tar.gz"
info "Checking: $RELEASE_URL"
curl --output /dev/null --silent --head --fail "$RELEASE_URL" \
    || error "Release v${VERSION} not found on GitHub. Check https://github.com/nervosnetwork/ckb/releases"
success "Release v${VERSION} confirmed."

# ── Stop service ──────────────────────────────────────────────────────────────
header "Stopping CKB node"
WAS_RUNNING=false
if service_is_active; then
    WAS_RUNNING=true
    info "Stopping systemd service '${SERVICE_NAME}'..."
    sudo systemctl stop "$SERVICE_NAME"
    # Wait up to 30s for graceful shutdown
    for i in $(seq 1 30); do
        service_is_active || break
        sleep 1
    done
    service_is_active && error "Service did not stop in time. Check: journalctl -u ${SERVICE_NAME}"
    success "Service stopped."
elif pgrep -x ckb > /dev/null 2>&1; then
    warn "CKB process found but no systemd service. Please stop it manually then re-run."
    exit 1
else
    info "Service not running — proceeding."
fi

# ── Download ──────────────────────────────────────────────────────────────────
header "Downloading CKB v${VERSION}"
ARCHIVE="$TEMP_DIR/ckb.tar.gz"
curl -L --progress-bar "$RELEASE_URL" -o "$ARCHIVE" \
    || error "Download failed."
success "Download complete."

# ── Extract ───────────────────────────────────────────────────────────────────
header "Extracting"
tar -xzf "$ARCHIVE" -C "$TEMP_DIR" || error "Extraction failed."
EXTRACTED_DIR="$TEMP_DIR/ckb_v${VERSION}_${ARCH_SUFFIX}"
[[ -d "$EXTRACTED_DIR" ]] \
    || error "Expected directory not found after extraction: $EXTRACTED_DIR"
success "Extracted to temp dir."

# ── Backup current binary ─────────────────────────────────────────────────────
if [[ -x "$CKB_HOME/ckb" ]]; then
    BACKUP="$CKB_HOME/ckb.v${CURRENT_VERSION}.bak"
    info "Backing up current binary → $BACKUP"
    cp "$CKB_HOME/ckb" "$BACKUP"
fi

# ── Install ───────────────────────────────────────────────────────────────────
header "Installing"
mkdir -p "$CKB_HOME"
# Copy everything except preserved files/dirs
rsync -a \
    --exclude=data \
    --exclude=ckb.toml \
    --exclude=ckb-miner.toml \
    --exclude='*.sh' \
    --exclude='*.bak' \
    --delete \
    "$EXTRACTED_DIR/" "$CKB_HOME/"
chmod +x "$CKB_HOME/ckb"
success "Files installed to $CKB_HOME"

# ── Verify ────────────────────────────────────────────────────────────────────
header "Verification"
NEW_VERSION="$("$CKB_HOME/ckb" --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' | head -1)"
[[ "$NEW_VERSION" == "$VERSION" ]] \
    || warn "Version mismatch — expected $VERSION, got $NEW_VERSION. Inspect manually."
success "CKB version: $("$CKB_HOME/ckb" --version)"

# ── Restart service ───────────────────────────────────────────────────────────
if [[ "$WAS_RUNNING" == true ]]; then
    header "Restarting service"
    sudo systemctl start "$SERVICE_NAME"
    sleep 2
    if service_is_active; then
        success "Service '${SERVICE_NAME}' is running."
    else
        warn "Service did not start. Check: journalctl -u ${SERVICE_NAME} -n 50"
    fi
else
    echo ""
    info "Node was not running before update. Start it manually when ready:"
    echo -e "    ${BOLD}cd $CKB_HOME && ./ckb run${RESET}"
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo -e "${GREEN}${BOLD}  CKB updated: v${CURRENT_VERSION} → v${VERSION}${RESET}"
echo -e "${GREEN}${BOLD}════════════════════════════════════════${RESET}"
echo ""
