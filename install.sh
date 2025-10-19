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
OMARCHY_HOOKS_DIR="$HOME/.config/omarchy/hooks"
THEME_SET_HOOK="$OMARCHY_HOOKS_DIR/theme-set"
SYNC_SCRIPT="omazed"
CONVERTER_SCRIPT="omazed-converter.sh"
ZED_THEMES_DIR="$HOME/.config/zed/themes"

log() { echo -e " $* "; }
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

check_omarchy_hook_support() {
    if command -v omarchy-hook >/dev/null 2>&1; then
        return 0
    fi

    if [[ -d "$HOME/.config/omarchy/hooks" ]]; then
        return 0
    fi

    return 1
}

check_dependencies() {
    local missing=()

    # Only require inotify-tools if we're using systemd (no hook support)
    if ! check_omarchy_hook_support; then
        if ! command -v inotifywait >/dev/null 2>&1; then
            missing+=("inotify-tools")
        fi
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        info "Install with: sudo pacman -S ${missing[*]}"
        exit 1
    fi

    log "Dependencies satisfied ✓"
}

check_zed() {

    # Try common Zed command names
    local zed_cmd=""
    for cmd in zeditor zed zedit zed-editor; do
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

    if [[ -e "$HOME/.config/omarchy/current/theme" ]]; then
        log "Omarchy theme system found ✓"
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

    if [[ ! -f "$SCRIPT_DIR/$SYNC_SCRIPT" ]]; then
        error "Sync script not found: $SCRIPT_DIR/$SYNC_SCRIPT"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_DIR/$CONVERTER_SCRIPT" ]]; then
        error "Converter script not found: $SCRIPT_DIR/$CONVERTER_SCRIPT"
        exit 1
    fi

    mkdir -p "$BIN_DIR"
    cp "$SCRIPT_DIR/$SYNC_SCRIPT" "$BIN_DIR/"
    cp "$SCRIPT_DIR/$CONVERTER_SCRIPT" "$BIN_DIR/"
    chmod +x "$BIN_DIR/$SYNC_SCRIPT"
    chmod +x "$BIN_DIR/$CONVERTER_SCRIPT"

    log "Sync Script installed to: $BIN_DIR/$SYNC_SCRIPT ✓"
    log "Converter Script installed to: $BIN_DIR/$CONVERTER_SCRIPT ✓"
}

install_themes() {

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
            cp "$theme_file" "$ZED_THEMES_DIR/"
            installed_count=$((installed_count + 1))
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
setup_omarchy_hook() {
    log "Setting up omarchy hook integration..."

    local hook_marker_start="# >>> omazed hook - do not edit >>>"
    local hook_marker_end="# <<< omazed hook - do not edit <<<"
    local hook_command='omazed set "$1"'

    # Create hooks directory if it doesn't exist
    mkdir -p "$OMARCHY_HOOKS_DIR"

    # Create hook file if it doesn't exist
    if [[ ! -f "$THEME_SET_HOOK" ]]; then
        cat > "$THEME_SET_HOOK" << 'EOF'
#!/bin/bash

# This hook is called with the snake-cased name of the theme that has just been set.
EOF
        chmod +x "$THEME_SET_HOOK"
        info "Created theme-set hook file"
    fi

    # Remove old omazed hook if it exists (for idempotency)
    if grep -q "$hook_marker_start" "$THEME_SET_HOOK" 2>/dev/null; then
        sed -i "/$hook_marker_start/,/$hook_marker_end/d" "$THEME_SET_HOOK"
        info "Removed old omazed hook"
    fi

    # Append omazed hook
    cat >> "$THEME_SET_HOOK" << EOF

$hook_marker_start
$hook_command
$hook_marker_end
EOF

    chmod +x "$THEME_SET_HOOK"
    log "Omarchy hook configured ✓"
    info "Theme changes will now trigger via omarchy hooks"
}

migrate_from_systemd() {
    # Check if user has existing systemd setup
    if systemctl --user is-enabled omazed.service 2>/dev/null; then
        info "Detected existing systemd setup, migrating to omarchy hooks..."

        # Stop and disable the service
        if systemctl --user stop omazed.service 2>/dev/null; then
            log "Stopped systemd service ✓"
        fi

        if systemctl --user disable omazed.service 2>/dev/null; then
            log "Disabled systemd service ✓"
        fi

        # Optionally remove the service file (user can manually clean up)
        if [[ -f "$SERVICE_DIR/omazed.service" ]]; then
            info "Old systemd service file remains at: $SERVICE_DIR/omazed.service"
            info "You can remove it manually if desired"
        fi

        log "Migration from systemd to hooks completed ✓"
        return 0
    fi
    return 1
}

create_systemd_service() {
    log "Setting up automatic theme sync (systemd method)..."

    info "Note: Omarchy hook system not detected, using systemd watcher"
    info "This requires inotify-tools and a background service"

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
    local using_hooks=$1

    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║                  INSTALLATION COMPLETE!                   ║
╚═══════════════════════════════════════════════════════════╝

🎉 Omazed is ready for live theme switching!

📋 WHAT WAS INSTALLED:
   • Sync script: $BIN_DIR/$SYNC_SCRIPT
   • Converter script: $BIN_DIR/$CONVERTER_SCRIPT
   • Zed themes: ~/.config/zed/themes/
EOF

    if [[ "$using_hooks" == "true" ]]; then
        cat << EOF
   • Omarchy hook: ~/.config/omarchy/hooks/theme-set

✅ LIVE THEME SWITCHING IS NOW ACTIVE!

   Your Zed theme will automatically change when you change your Omarchy theme.
   Integration via omarchy hooks - no background service needed!

🔧 MANUAL COMMANDS:
   # Set a specific theme
   omazed set "theme-name"

   # Test current setup
   omazed test

   # Sync current theme once
   omazed sync
EOF
    else
        cat << EOF
   • Systemd service

✅ LIVE THEME SWITCHING IS NOW ACTIVE!

   Your Zed theme will automatically change when you change your Omarchy theme.
   No further action needed!

🔧 MANUAL COMMANDS (if needed):
   # Start the theme watcher (systemd service)
   omazed start

   # Stop systemd service
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
EOF
    fi

    cat << EOF

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

    local using_hooks="false"
    if check_omarchy_hook_support; then
        log "Omarchy hook system available - using hook integration"
        using_hooks="true"

        if migrate_from_systemd; then
            info "Successfully migrated from systemd to hooks"
        fi

        setup_omarchy_hook
    else
        warn "Omarchy hook system not available - using systemd watcher"
        info "Consider updating omarchy for hook support in the future"
        create_systemd_service
    fi

    test_installation

    print_completion "$using_hooks"
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
1. Checks for required dependencies (inotify-tools)
2. Installs the sync script to ~/.local/bin/
3. Copies themes to ~/.config/zed/themes/
4. Sets up systemd service for auto-start
5. Tests the installation

After installation, your Zed theme will automatically sync with your Omarchy system theme.
EOF
    exit 0
fi

main "$@"
