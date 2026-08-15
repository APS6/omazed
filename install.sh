#!/bin/bash

# Simple installation script for Omazed
# Live theme switching for zed in omarchy - installs the sync tool and generator

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
OMARCHY_HOOKS_DIR="$HOME/.config/omarchy/hooks"
THEME_SET_HOOK="$OMARCHY_HOOKS_DIR/theme-set"
MAIN_SCRIPT="omazed"
GENERATOR_SCRIPT="omazed-generator.sh"
TEMPLATE_FILE="omazed-theme.tpl"

log() { echo -e "${GREEN}[INFO]${NC} $* "; }
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

    if [[ -d "$HOME/.config/omarchy/hooks/theme-set.d" ]]; then
        return 0
    fi

    if [[ -d "$HOME/.config/omarchy/hooks" ]]; then
        return 0
    fi

    return 1
}

detect_omarchy_version() {
    if command -v omarchy-version >/dev/null 2>&1; then
        local version
        version=$(omarchy-version 2>/dev/null | cut -d. -f1)
        if [[ "$version" =~ ^[0-9]+$ ]] && (( version >= 4 )); then
            echo "v4"
            return
        fi
    fi
    if [[ -d "$HOME/.local/state/omarchy/current/theme" ]]; then
        echo "v4"
    else
        echo "v3"
    fi
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
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_omarchy() {
    local version
    version=$(detect_omarchy_version)

    if [[ "$version" == "v4" ]]; then
        log "Omarchy v4 theme system found ✓"
    elif [[ -e "$HOME/.config/omarchy/current/theme" ]]; then
        log "Omarchy v3 theme system found ✓"
    else
        warn "Omarchy theme file not found"
        info "Expected: $HOME/.local/state/omarchy/current/theme or $HOME/.config/omarchy/current/theme"
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

install_script() {

    if [[ ! -f "$SCRIPT_DIR/$MAIN_SCRIPT" ]]; then
        error "Sync script not found: $SCRIPT_DIR/$MAIN_SCRIPT"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_DIR/$GENERATOR_SCRIPT" ]]; then
        error "Generator script not found: $SCRIPT_DIR/$GENERATOR_SCRIPT"
        exit 1
    fi

    if [[ ! -f "$SCRIPT_DIR/$TEMPLATE_FILE" ]]; then
        error "Template file not found: $SCRIPT_DIR/$TEMPLATE_FILE"
        exit 1
    fi

    mkdir -p "$BIN_DIR"
    cp "$SCRIPT_DIR/$MAIN_SCRIPT" "$BIN_DIR/"
    cp "$SCRIPT_DIR/$GENERATOR_SCRIPT" "$BIN_DIR/"
    cp "$SCRIPT_DIR/$TEMPLATE_FILE" "$BIN_DIR/"
    chmod +x "$BIN_DIR/$MAIN_SCRIPT"
    chmod +x "$BIN_DIR/$GENERATOR_SCRIPT"

    log "Sync Script installed to: $BIN_DIR/$MAIN_SCRIPT ✓"
    log "Generator script installed to: $BIN_DIR/$GENERATOR_SCRIPT ✓"
    log "Template file installed to: $BIN_DIR/$TEMPLATE_FILE ✓"
}

setup_omarchy_hook() {
    log "Setting up omarchy hook integration..."

    local hook_marker_start="# >>> omazed hook - do not edit >>>"
    local hook_marker_end="# <<< omazed hook - do not edit <<<"
    local version
    version=$(detect_omarchy_version)

    if [[ "$version" == "v4" ]]; then
        # v4 uses .d directory
        local hook_dir="$OMARCHY_HOOKS_DIR/theme-set.d"
        mkdir -p "$hook_dir"
        local v4_hook_file="$hook_dir/omazed"

        cat > "$v4_hook_file" << 'EOF'
#!/bin/bash
omazed set "$1"
EOF
        chmod +x "$v4_hook_file"
        info "Created v4 omarchy hook: $v4_hook_file"

        # Cleanup old v3 hook if it exists
        if [[ -f "$THEME_SET_HOOK" ]] && grep -q "$hook_marker_start" "$THEME_SET_HOOK" 2>/dev/null; then
            sed -i "/$hook_marker_start/,/$hook_marker_end/d" "$THEME_SET_HOOK"
            info "Removed legacy v3 omazed hook"
        fi

        log "Omarchy hook configured (v4) ✓"
    else
        # v3 uses single file injection
        mkdir -p "$OMARCHY_HOOKS_DIR"

        if [[ ! -f "$THEME_SET_HOOK" ]]; then
            cat > "$THEME_SET_HOOK" << 'EOF'
#!/bin/bash

# This hook is called with the snake-cased name of the theme that has just been set.
EOF
            chmod +x "$THEME_SET_HOOK"
            info "Created theme-set hook file"
        fi

        if grep -q "$hook_marker_start" "$THEME_SET_HOOK" 2>/dev/null; then
            sed -i "/$hook_marker_start/,/$hook_marker_end/d" "$THEME_SET_HOOK"
            info "Removed old omazed hook"
        fi

        local hook_command='omazed set "$1"'

        cat >> "$THEME_SET_HOOK" << EOF

$hook_marker_start
$hook_command
$hook_marker_end
EOF

        chmod +x "$THEME_SET_HOOK"
        log "Omarchy hook configured (v3) ✓"
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
   • Sync script: $BIN_DIR/$MAIN_SCRIPT
   • Generator script: $BIN_DIR/$GENERATOR_SCRIPT
   • Generated Zed theme: ~/.config/zed/themes/omazed.json
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

   # Sync current theme once
   omazed sync
EOF
    else
        cat << EOF

✅ LIVE THEME SWITCHING IS NOW ACTIVE!

   Your Zed theme will automatically change when you change your Omarchy theme.
   No further action needed!

🔧 MANUAL COMMANDS (if needed):
   # Sync theme once and exit
   omazed sync

EOF
    fi

    cat << EOF

🎨 Try it: Change your Omarchy theme and watch Zed follow along automatically!

EOF
}

main() {
    print_banner

    log "Starting installation..."

    check_zed
    check_omarchy
    install_script
    cleanup_old_themes
    local using_hooks="false"
    if check_omarchy_hook_support; then
        setup_omarchy_hook
    else
        error "Omarchy hook system not available. Please update omarchy or install a older version of omazed < 1.2"
        return 1
    fi

    if "$BIN_DIR/$MAIN_SCRIPT" sync; then
        log "Initial sync completed"
    else
        warn "Initial sync failed - run: omazed sync"
    fi

    log "Installation completed! Live theme switching is now active! 🎉"
}

cleanup_old_themes() {
    local themes_dir="$HOME/.config/zed/themes"
    local removed=0

    if [[ ! -d "$themes_dir" ]]; then
        return 0
    fi

    shopt -s nullglob
    for theme_file in "$themes_dir"/*.json; do
        if [[ "$(basename "$theme_file")" != "omazed.json" ]]; then
            rm -f "$theme_file"
            removed=$((removed + 1))
        fi
    done
    shopt -u nullglob

    if [[ $removed -gt 0 ]]; then
        log "Removed $removed old Zed theme file(s)"
    fi
}

# Handle help
if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
    cat << EOF
Omazed Installer - Live theme switching for zed in omarchy

USAGE: $0 [OPTIONS]

OPTIONS:
    -h, --help    Show this help

This script:
1. Installs the sync script to ~/.local/bin/
2. Installs the generator and template
3. Sets up automatic theme sync hook

After installation, your Zed theme will automatically sync with your Omarchy system theme.
EOF
    exit 0
fi

main "$@"
