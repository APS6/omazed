#!/bin/bash

# Simple installation script for Omazed
# Live theme switching for zed in omarchy - just installs themes and sets up the sync tool

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
SYNC_SCRIPT="omazed"
ZED_THEMES_DIR="$HOME/.config/zed/themes"

log() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

print_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║                        Omazed                             ║
║           Live theme switching for zed in omarchy         ║
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

    # Create Zed themes directory
    mkdir -p "$ZED_THEMES_DIR"

    if [[ ! -d "$SCRIPT_DIR/themes" ]]; then
        error "Themes directory not found: $SCRIPT_DIR/themes"
        return 1
    fi

    local installed_count=0

    for theme_file in "$SCRIPT_DIR/themes"/*.json; do
        if [[ -f "$theme_file" ]]; then
            local basename=$(basename "$theme_file")

            # Validate JSON
            if jq empty "$theme_file" 2>/dev/null; then
                cp "$theme_file" "$ZED_THEMES_DIR/"
                log "Installed theme: $basename"
                installed_count=$((installed_count + 1))
            else
                warn "Skipping invalid JSON: $basename"
            fi
        fi
    done

    if [[ $installed_count -gt 0 ]]; then
        log "Installed $installed_count theme(s) to $ZED_THEMES_DIR"
        return 0
    else
        error "No themes were installed"
        return 1
    fi
}
create_systemd_service() {
    log "Setting up automatic theme sync..."

    mkdir -p "$SERVICE_DIR"
    cp "$SCRIPT_DIR/omazed.service" "$SERVICE_DIR/"

    # Update paths in service file
    sed -i "s|%h|$HOME|g" "$SERVICE_DIR/omazed.service"

    # Enable and start service automatically
    systemctl --user daemon-reload
    systemctl --user enable omazed.service
    systemctl --user start omazed.service
    sleep 2

    if systemctl --user is-active --quiet omazed.service; then
        log "Automatic theme sync enabled ✓"
    else
        warn "Service setup failed - you can start manually with:"
        warn "  systemctl --user start omazed.service"
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
║                  INSTALLATION COMPLETE!                   ║
╚═══════════════════════════════════════════════════════════╝

🎉 Omazed is ready for live theme switching!

📋 WHAT WAS INSTALLED:
   • Sync script: $BIN_DIR/$SYNC_SCRIPT
   • Zed themes: ~/.config/zed/themes/
   • Systemd service

✅ LIVE THEME SWITCHING IS NOW ACTIVE!

   Your Zed theme will automatically change when you change your Omarchy theme.
   No further action needed!

🔧 MANUAL COMMANDS (if needed):
   # Start the theme watcher (systemd service)
   omazed start

   # Stop running systemd service and/or daemons
   omazed stop

   # Check if omazed is running
   omazed status

   # Test current setup
   omazed test

   # Sync theme once and exit
   omazed sync

📊 SERVICE MANAGEMENT:
   systemctl --user status omazed.service
   systemctl --user restart omazed.service

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
    log "Installation completed! Live theme switching is now active! 🎉"
}

# Handle help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat << EOF
Omazed Installer - Live theme switching for zed in omarchy

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
