#!/bin/bash

# Simple installation script for Omarchy Zed Theme Sync
# No extension complexity - just installs themes and sets up the sync tool

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SERVICE_DIR="$HOME/.config/systemd/user"
SYNC_SCRIPT="omarchy-zed-theme-sync.sh"

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

print_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              Omarchy Zed Theme Sync                       ║
║              Simple Installation                          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

check_dependencies() {
    log "Checking dependencies..."

    local missing=()

    if ! command -v inotifywait >/dev/null 2>&1; then
        missing+=("inotify-tools")
    fi

    if ! command -v jq >/dev/null 2>&1; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        info "Install with: sudo pacman -S ${missing[*]}"
        exit 1
    fi

    log "Dependencies satisfied ✓"
}

check_zed() {
    log "Checking for Zed editor..."

    # Try common Zed command names
    local zed_cmd=""
    for cmd in zeditor zed; do
        if command -v "$cmd" >/dev/null 2>&1; then
            zed_cmd="$cmd"
            break
        fi
    done

    if [[ -n "$zed_cmd" ]]; then
        log "Zed found: $zed_cmd ✓"
    else
        warn "Zed not found in PATH"
        info "Install Zed from: https://zed.dev"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_omarchy() {
    log "Checking Omarchy theme system..."

    if [[ -e "$HOME/.config/omarchy/current/theme" ]]; then
        log "Omarchy theme system found ✓"

        # Show current theme if possible
        if [[ -f "$HOME/.config/omarchy/current/theme" ]]; then
            local current_theme
            current_theme=$(cat "$HOME/.config/omarchy/current/theme" 2>/dev/null | tr -d '\n\r' || echo "")
            if [[ -n "$current_theme" ]]; then
                info "Current theme: $current_theme"
            fi
        fi
    else
        warn "Omarchy theme file not found"
        info "Expected: $HOME/.config/omarchy/current/theme"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_script() {
    log "Installing sync script..."

    if [[ ! -f "$SCRIPT_DIR/$SYNC_SCRIPT" ]]; then
        error "Sync script not found: $SCRIPT_DIR/$SYNC_SCRIPT"
        exit 1
    fi

    mkdir -p "$BIN_DIR"
    cp "$SCRIPT_DIR/$SYNC_SCRIPT" "$BIN_DIR/"
    chmod +x "$BIN_DIR/$SYNC_SCRIPT"

    log "Script installed to: $BIN_DIR/$SYNC_SCRIPT ✓"
}

install_themes() {
    log "Installing themes to Zed..."

    # Use the original script to install themes (has correct path to themes)
    if "$SCRIPT_DIR/$SYNC_SCRIPT" install; then
        log "Themes installed successfully ✓"
    else
        error "Theme installation failed"
        return 1
    fi
}

create_systemd_service() {
    log "Setting up automatic theme sync..."

    mkdir -p "$SERVICE_DIR"
    cp "$SCRIPT_DIR/omarchy-zed-sync.service" "$SERVICE_DIR/"

    # Update paths in service file
    sed -i "s|%h|$HOME|g" "$SERVICE_DIR/omarchy-zed-sync.service"

    # Enable and start service automatically
    systemctl --user daemon-reload
    systemctl --user enable omarchy-zed-sync.service
    systemctl --user start omarchy-zed-sync.service
    sleep 2

    if systemctl --user is-active --quiet omarchy-zed-sync.service; then
        log "Automatic theme sync enabled ✓"
    else
        warn "Service setup failed - you can start manually with:"
        warn "  systemctl --user start omarchy-zed-sync.service"
    fi
}

test_installation() {
    log "Testing installation..."

    if "$BIN_DIR/$SYNC_SCRIPT" test; then
        log "Installation test passed ✓"
    else
        warn "Installation test failed"
    fi
}

print_completion() {
    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║                  INSTALLATION COMPLETE!                  ║
╚═══════════════════════════════════════════════════════════╝

🎉 Omarchy Zed Theme Sync is ready!

📋 WHAT WAS INSTALLED:
   • Sync script: $BIN_DIR/$SYNC_SCRIPT
   • Zed themes: ~/.config/zed/themes/
   • Systemd service (optional)

✅ AUTOMATIC SYNC IS NOW RUNNING!

   Your Zed theme will automatically change when you change your Omarchy theme.
   No further action needed!

🔧 MANUAL COMMANDS (if needed):
   # Test setup:
   $BIN_DIR/$SYNC_SCRIPT test

   # Manual sync:
   $BIN_DIR/$SYNC_SCRIPT sync

📊 SERVICE MANAGEMENT:
   systemctl --user status omarchy-zed-sync.service
   systemctl --user restart omarchy-zed-sync.service

🎨 Try it: Change your Omarchy theme and watch Zed follow along automatically!

EOF
}

main() {
    print_banner

    log "Starting installation..."

    check_dependencies
    check_zed
    check_omarchy
    install_script
    install_themes
    create_systemd_service
    test_installation

    print_completion
    log "Installation completed! Theme sync is now running automatically! 🎉"
}

# Handle help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat << EOF
Omarchy Zed Theme Sync Installer

USAGE: $0 [OPTIONS]

OPTIONS:
    -h, --help    Show this help

This script:
1. Checks for required dependencies (inotify-tools, jq)
2. Installs the sync script to ~/.local/bin/
3. Copies themes to ~/.config/zed/themes/
4. Sets up systemd service for auto-start
5. Tests the installation

After installation, your Zed theme will automatically sync with your Omarchy system theme.
EOF
    exit 0
fi

main "$@"
