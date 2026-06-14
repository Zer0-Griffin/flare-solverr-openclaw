#!/bin/bash
# FlareSolverr-OpenClaw Installer for Linux/macOS
# Usage: curl -sSL https://raw.githubusercontent.com/Zer0-Griffin/flaresolverr-openclaw/main/install.sh | bash

set -e

INSTALL_DIR="$HOME/.openclaw/flare-solverr"
CONFIG_FILE="$INSTALL_DIR/config.ini"

echo "[FlareSolverr-OpenClaw] Installing..."

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${CYAN}[FlareSolverr-OpenClaw] $*${NC}"; }
ok()    { echo -e "${GREEN}[FlareSolverr-OpenClaw] $*${NC}"; }
warn()  { echo -e "${YELLOW}[FlareSolverr-OpenClaw] Warning: $*${NC}"; }

# Create installation directory
mkdir -p "$INSTALL_DIR"
info "Installation directory: $INSTALL_DIR"

# Detect browser path
BROWSER_PATH=""
for b in \
    "/usr/bin/google-chrome" \
    "/usr/bin/chromium-browser" \
    "/usr/bin/chromium" \
    "/snap/bin/chromium"; do
    if [ -x "$b" ]; then
        BROWSER_PATH="$b"
        break
    fi
done

# Check for macOS Chrome
if [[ "$(uname)" == "Darwin" ]]; then
    for b in \
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
        "/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"; do
        if [ -x "$b" ]; then
            BROWSER_PATH="$b"
            break
        fi
    done
fi

if [ -n "$BROWSER_PATH" ]; then
    ok "Detected browser: $BROWSER_PATH"
else
    warn "No supported browser found. Will install from source (requires Python 3.11+)."
fi

# Determine architecture
ARCH=$(uname -m)
case "$ARCH" in
    x86_64|amd64) ARCH="linux_amd64" ;;
    aarch64|arm64) ARCH="linux_arm64" ;;
    *) warn "Unknown architecture: $ARCH. Attempting source install." ;;
esac

# Download precompiled binary if available and arch is supported
if [[ "$ARCH" == "linux_amd64" || "$ARCH" == "linux_arm64" ]]; then
    BINARY_URL="https://github.com/FlareSolverr/FlareSolverr/releases/latest/download/FlareSolverr_${ARCH}.tar.gz"
    BIN_PATH="$INSTALL_DIR/bin/flaresolverr"

    info "Downloading FlareSolverr binary for $ARCH..."
    curl -sSL "$BINARY_URL" -o "$INSTALL_DIR/flaresolverr.tar.gz"

    if [ $? -eq 0 ] && [ -f "$INSTALL_DIR/flaresolverr.tar.gz" ]; then
        mkdir -p "$INSTALL_DIR/bin"
        tar xzf "$INSTALL_DIR/flaresolverr.tar.gz" -C "$INSTALL_DIR/bin/" --strip-components=1 2>/dev/null || \
        tar xzf "$INSTALL_DIR/flaresolverr.tar.gz" -C "$INSTALL_DIR/"

        rm -f "$INSTALL_DIR/flaresolverr.tar.gz"

        if [ -x "$BIN_PATH" ] || [ -f "$INSTALL_DIR/flaresolverr" ]; then
            ok "Binary installed."
        fi
    else
        warn "Download failed. Falling back to source install."
    fi
fi

# Source install fallback (or primary)
if [[ ! -x "$BIN_PATH" && ! -f "$INSTALL_DIR/flaresolverr" ]]; then
    info "Installing from source..."

    if ! command -v python3 &>/dev/null; then
        warn "Python 3 not found. Trying to install..."
        if command -v apt-get &>/dev/null; then
            sudo apt-get update && sudo apt-get install -y python3 python3-pip
        elif command -v brew &>/dev/null; then
            brew install python3
        fi
    fi

    if ! command -v pip3 &>/dev/null; then
        warn "pip3 not found. Installing..."
        python3 -m ensurepip 2>/dev/null || true
    fi

    SRC_DIR="$INSTALL_DIR/source"
    rm -rf "$SRC_DIR"
    git clone https://github.com/FlareSolverr/FlareSolverr.git "$SRC_DIR"

    info "Installing Python dependencies..."
    pip3 install -r "$SRC_DIR/requirements.txt" --user 2>&1 | tail -5 || \
    python3 -m pip install -r "$SRC_DIR/requirements.txt" --user 2>&1 | tail -5

fi

# Write config file
cat > "$CONFIG_FILE" << EOF
[flaresolverr]
port = 8191
timeout_seconds = 60
language = en-US
browser = auto
url_base = http://localhost:8191

; Detected browser path (optional, auto-detects if empty)
# browser_path = $BROWSER_PATH
EOF

ok "Config written to: $CONFIG_FILE"

# Write startup script
cat > "$INSTALL_DIR/start.sh" << 'SCRIPT'
#!/bin/bash
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$INSTALL_DIR/bin/flaresolverr"
SRC="$INSTALL_DIR/source/flaresolverr.py"

if [ -x "$BIN" ]; then
    echo "[FlareSolverr-OpenClaw] Starting on port 8191..."
    exec "$BIN"
elif [ -f "$SRC" ]; then
    echo "[FlareSolverr-OpenClaw] Starting from source..."
    python3 -u "$SRC"
else
    echo "[FlareSolverr-OpenClaw] ERROR: No binary or source found."
    exit 1
fi
SCRIPT
chmod +x "$INSTALL_DIR/start.sh"
ok "Startup script: $INSTALL_DIR/start.sh"

# Write stop script
cat > "$INSTALL_DIR/stop.sh" << 'SCRIPT'
#!/bin/bash
pkill -f flaresolverr || true
echo "[FlareSolverr-OpenClaw] Stopped."
SCRIPT
chmod +x "$INSTALL_DIR/stop.sh"
ok "Stop script: $INSTALL_DIR/stop.sh"

# Add to PATH if not already there
case ":$PATH:" in
    *":$INSTALL_DIR/bin:"*) ;;
    *) export PATH="$INSTALL_DIR/bin:$PATH"; echo "[FlareSolverr-OpenClaw] Added to PATH (current session).";;
esac

# Update OpenClaw TOOLS.md if it exists
TOOLS_FILE="$HOME/.openclaw/workspace/TOOLS.md"
if [ -f "$TOOLS_FILE" ]; then
    if ! grep -q "FlareSolverr" "$TOOLS_FILE"; then
        info "Adding FlareSolverr entry to TOOLS.md..."
        echo "" >> "$TOOLS_FILE"
        echo "### FlareSolverr" >> "$TOOLS_FILE"
        echo "- URL: http://localhost:8191/" >> "$TOOLS_FILE"
        echo "- Used for Cloudflare bypass via web_fetch proxy" >> "$TOOLS_FILE"
        ok "TOOLS.md updated."
    else
        warn "FlareSolverr entry already exists in TOOLS.md."
    fi
fi

echo ""
echo "========================================"
echo "  Installation Complete!"
echo "========================================"
echo ""
echo "To start FlareSolverr:"
echo "  cd $INSTALL_DIR"
echo "  ./start.sh"
echo ""
echo "Config file: $CONFIG_FILE"
