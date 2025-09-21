#!/bin/bash

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OMARCHY_THEME_PATH="$HOME/.config/omarchy/current/theme"
ZED_CONFIG_DIR="$HOME/.config/zed"
ZED_THEMES_DIR="$ZED_CONFIG_DIR/themes"
ZED_SETTINGS_PATH="$ZED_CONFIG_DIR/settings.json"
LOG_FILE="$HOME/.local/share/omarchy-zed-sync/sync.log"
LOCK_FILE="/tmp/omarchy-zed-sync.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${RED}[ERROR]${NC} $*"
}


# Check dependencies
check_deps() {
    local missing=()

    for cmd in inotifywait jq; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing dependencies: ${missing[*]}"
        info "Install with: sudo pacman -S inotify-tools jq"
        exit 1
    fi

    return 0
}

# Install themes to Zed
install_themes() {
    info "Installing themes to Zed..."

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
                success "Installed theme: $basename"
                installed_count=$((installed_count + 1))
            else
                warn "Skipping invalid JSON: $basename"
            fi
        fi
    done

    if [[ $installed_count -gt 0 ]]; then
        success "Installed $installed_count theme(s) to $ZED_THEMES_DIR"
        return 0
    else
        error "No themes were installed"
        return 1
    fi
}

# Get current Omarchy theme
get_current_theme() {
    local theme=""

    # Try reading file content first
    if [[ -f "$OMARCHY_THEME_PATH" ]]; then
        theme=$(cat "$OMARCHY_THEME_PATH" 2>/dev/null | tr -d '\n\r' || echo "")
    fi

    # If empty, try resolving symlink
    if [[ -z "$theme" && -L "$OMARCHY_THEME_PATH" ]]; then
        local link_target
        link_target=$(readlink "$OMARCHY_THEME_PATH" 2>/dev/null || echo "")
        if [[ -n "$link_target" ]]; then
            theme=$(basename "$link_target" | sed 's/\.theme$//' || echo "")
        fi
    fi

    echo "$theme"
}

# Map Omarchy theme name to Zed theme name using regex transformation
map_theme_name() {
    local omarchy_theme="$1"

    # Transform: capitalize first letter and letters after dashes, then replace dashes with spaces
    echo "$omarchy_theme" | sed 's/\(^\|[-]\)\([a-z]\)/\1\u\2/g; s/-/ /g'
}

# Update Zed settings
update_zed_theme() {
    local theme_name="$1"

    info "Setting Zed theme to: $theme_name"

    # Safety check - make sure we're not interfering with critical boot processes
    if [[ -e "/tmp/omarchy-boot-in-progress" ]]; then
        info "Omarchy boot in progress, deferring theme update"
        return 0
    fi

    # Create config directory if it doesn't exist
    mkdir -p "$ZED_CONFIG_DIR"

    # Create settings file if it doesn't exist
    if [[ ! -f "$ZED_SETTINGS_PATH" ]]; then
        echo '{"theme": "'"$theme_name"'"}' > "$ZED_SETTINGS_PATH"
    else
        # Update existing theme line or add new one
        if grep -q '"theme"' "$ZED_SETTINGS_PATH"; then
            # Replace existing theme line
            sed -i 's/"theme"[[:space:]]*:[[:space:]]*"[^"]*"/"theme": "'"$theme_name"'"/' "$ZED_SETTINGS_PATH"
        else
            # Add theme before the last closing brace
            sed -i '$s/}/,\n  "theme": "'"$theme_name"'"\n}/' "$ZED_SETTINGS_PATH"
        fi
    fi

    # Verify the update worked
    if grep -q "\"theme\":[[:space:]]*\"$theme_name\"" "$ZED_SETTINGS_PATH"; then
        success "Updated Zed settings.json"
        return 0
    else
        error "Failed to update settings"
        return 1
    fi
}

# Handle theme change
handle_theme_change() {
    # Safety check - don't interfere if Omarchy is still booting
    if ! pgrep -f "omarchy" >/dev/null 2>&1 && [[ ! -e "$OMARCHY_THEME_PATH" ]]; then
        info "Omarchy not ready yet, skipping theme sync"
        return 0
    fi

    local current_theme
    current_theme=$(get_current_theme)

    if [[ -z "$current_theme" ]]; then
        warn "Could not determine current Omarchy theme"
        return 1
    fi

    info "Detected Omarchy theme: $current_theme"

    # Map to Zed theme name
    local zed_theme
    zed_theme=$(map_theme_name "$current_theme")

    # Check if corresponding theme file exists in Zed themes directory
    local theme_file="$ZED_THEMES_DIR/${current_theme}.json"
    if [[ ! -f "$theme_file" ]]; then
        warn "Theme file not found: $theme_file"
        info "Available themes: $(ls -1 "$ZED_THEMES_DIR"/*.json 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
        info "Skipping Zed theme update - no corresponding theme file available"
        return 0
    fi

    # Update Zed settings
    if update_zed_theme "$zed_theme"; then
        success "Theme sync completed: $current_theme → $zed_theme"
    else
        error "Failed to sync theme"
        return 1
    fi
    return 0
}

# Watch for theme changes
start_watching() {
    info "Starting theme watcher..."
    info "Watching: $OMARCHY_THEME_PATH"
    info "Zed themes: $ZED_THEMES_DIR"
    info "Zed settings: $ZED_SETTINGS_PATH"

    # Wait for Omarchy to fully initialize before starting
    info "Waiting for Omarchy theme system to be ready..."
    local wait_count=0
    while [[ $wait_count -lt 30 ]]; do
        if [[ -e "$OMARCHY_THEME_PATH" ]]; then
            # Additional check - make sure the file is stable
            sleep 2
            if [[ -e "$OMARCHY_THEME_PATH" ]]; then
                break
            fi
        fi
        sleep 1
        ((wait_count++))
    done

    if [[ $wait_count -ge 30 ]]; then
        warn "Timeout waiting for Omarchy theme system - continuing anyway"
    else
        info "Omarchy theme system is ready"
    fi

    # Set initial theme
    handle_theme_change

    # Watch for changes
    local watch_dir
    watch_dir=$(dirname "$OMARCHY_THEME_PATH")
    local watch_file
    watch_file=$(basename "$OMARCHY_THEME_PATH")

    info "Monitoring $watch_dir for changes to $watch_file"

    while true; do
        if inotifywait -e modify,move,delete,create -qq "$watch_dir" 2>/dev/null; then
            sleep 0.5  # Brief delay for file operations to complete
            handle_theme_change
        fi
    done
}

# Test current setup
test_setup() {
    info "Testing current setup..."

    # Check Omarchy theme file
    if [[ ! -e "$OMARCHY_THEME_PATH" ]]; then
        error "Omarchy theme file not found: $OMARCHY_THEME_PATH"
        return 1
    fi

    # Check current theme
    local current_theme
    current_theme=$(get_current_theme)
    if [[ -n "$current_theme" ]]; then
        success "Current Omarchy theme: $current_theme"
    else
        error "Could not detect current theme"
        return 1
    fi

    # Check Zed config
    if [[ -d "$ZED_CONFIG_DIR" ]]; then
        success "Zed config directory exists: $ZED_CONFIG_DIR"
    else
        warn "Zed config directory not found (will be created)"
    fi

    # Check installed themes
    local theme_count=0
    if [[ -d "$ZED_THEMES_DIR" ]]; then
        theme_count=$(find "$ZED_THEMES_DIR" -name "*.json" | wc -l)
        success "Found $theme_count theme(s) in Zed themes directory"
    else
        warn "No Zed themes directory found"
    fi

    # Test theme mapping
    local zed_theme
    zed_theme=$(map_theme_name "$current_theme")
    success "Theme mapping: $current_theme → $zed_theme"

    # Test JSON manipulation
    if echo '{}' | jq '.theme = "test"' >/dev/null 2>&1; then
        success "JSON manipulation working"
    else
        error "JSON manipulation failed"
        return 1
    fi

    success "Setup test completed successfully"
    return 0
}

# Stop any running instance
stop_watcher() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            info "Stopping running watcher (PID: $pid)"
            kill "$pid"
            sleep 1
            if kill -0 "$pid" 2>/dev/null; then
                warn "Force killing watcher"
                kill -9 "$pid" 2>/dev/null || true
            fi
            rm -f "$LOCK_FILE"
            success "Watcher stopped"
        else
            warn "Stale lock file removed"
            rm -f "$LOCK_FILE"
        fi
    else
        info "No running watcher found"
    fi
}

# Create lock file
create_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            error "Another instance is already running (PID: $pid)"
            exit 1
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    echo $$ > "$LOCK_FILE"
}

# Cleanup
cleanup() {
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    return 0
}

trap cleanup EXIT
trap 'error "Interrupted"; exit 1' INT TERM

# Print usage
usage() {
    cat << EOF
Omarchy Zed Theme Sync

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    install     Install themes to Zed and set up sync
    watch       Start watching for theme changes (default)
    test        Test current setup
    stop        Stop any running watcher
    sync        Sync theme once and exit

OPTIONS:
    -h, --help  Show this help
    -d, --daemon Run as background daemon

EOF
}

# Main function
main() {
    local command="watch"
    local daemon=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            install)
                command="install"
                shift
                ;;
            watch)
                command="watch"
                shift
                ;;
            test)
                command="test"
                shift
                ;;
            stop)
                command="stop"
                shift
                ;;
            sync)
                command="sync"
                shift
                ;;
            -d|--daemon)
                daemon=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # Execute command
    case $command in
        install)
            info "Installing Omarchy Zed Theme Sync..."
            check_deps
            install_themes
            success "Installation complete! Run '$0' to start watching."
            ;;
        test)
            check_deps
            test_setup
            ;;
        stop)
            stop_watcher
            ;;
        sync)
            check_deps
            handle_theme_change
            ;;
        watch)
            check_deps
            if [[ "$daemon" == true ]]; then
                info "Starting theme sync service..."
                create_lock
                start_watching >> "$LOG_FILE" 2>&1 &
                echo $! > "$LOCK_FILE"
                success "Theme sync started automatically"
            else
                create_lock
                start_watching
            fi
            ;;
    esac
}

main "$@"
