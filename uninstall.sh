#!/bin/bash

# Omazed Uninstaller
# Cleanly removes the live theme switching tool and all associated components

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BIN_DIR="$HOME/.local/bin"
INSTALL_DIR="$HOME/.local/share/omazed"
SERVICE_DIR="$HOME/.config/systemd/user"
SYNC_SCRIPT="$BIN_DIR/omazed"
SERVICE_FILE="$SERVICE_DIR/omazed.service"
LOG_FILE="$INSTALL_DIR/uninstall.log"
LOCK_FILE="/tmp/omazed.lock"

# Ensure log directory exists for this run
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${GREEN}[INFO]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${RED}[ERROR]${NC} $*"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE" 2>/dev/null || echo -e "${BLUE}[INFO]${NC} $*"
}

# Print banner
print_banner() {
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║                     Omazed Uninstaller                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
}

# Check what's currently installed
check_installation() {
    info "Checking current installation..."

    local found_components=()

    if [[ -f "$SYNC_SCRIPT" ]]; then
        found_components+=("Theme Sync Script")
    fi

    if [[ -f "$SERVICE_FILE" ]]; then
        found_components+=("Systemd Service")
    fi

    if [[ -d "$INSTALL_DIR" ]]; then
        found_components+=("Installation Directory")
    fi

    if systemctl --user is-enabled omazed.service >/dev/null 2>&1; then
        found_components+=("Enabled Service")
    fi

    if systemctl --user is-active omazed.service >/dev/null 2>&1; then
        found_components+=("Running Service")
    fi

    if [[ ${#found_components[@]} -eq 0 ]]; then
        warn "No installation components found"
        return 1
    else
        info "Found components: ${found_components[*]}"
        return 0
    fi
}

# Stop and disable systemd service
remove_service() {
    info "Removing systemd service..."

    # Stop the service if running
    if systemctl --user is-active --quiet omazed.service 2>/dev/null; then
        log "Stopping omazed service..."
        if systemctl --user stop omazed.service; then
            log "Service stopped successfully ✓"
        else
            warn "Failed to stop service gracefully"
        fi
    fi

    # Disable the service if enabled
    if systemctl --user is-enabled --quiet omazed.service 2>/dev/null; then
        log "Disabling omazed service..."
        if systemctl --user disable omazed.service; then
            log "Service disabled successfully ✓"
        else
            warn "Failed to disable service"
        fi
    fi

    # Remove service file
    if [[ -f "$SERVICE_FILE" ]]; then
        log "Removing service file..."
        if rm -f "$SERVICE_FILE"; then
            log "Service file removed ✓"
        else
            error "Failed to remove service file"
        fi
    fi

    # Reload systemd daemon
    if systemctl --user daemon-reload; then
        log "Systemd daemon reloaded ✓"
    else
        warn "Failed to reload systemd daemon"
    fi
}

# Remove theme watcher script
remove_sync_script() {
    info "Removing theme sync script..."

    # Stop any running sync process
    if [[ -f "$LOCK_FILE" ]]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            log "Stopping sync process (PID: $pid)..."
            if kill "$pid" 2>/dev/null; then
                sleep 1
                if kill -0 "$pid" 2>/dev/null; then
                    warn "Force killing sync process"
                    kill -9 "$pid" 2>/dev/null || true
                fi
            fi
        fi
        rm -f "$LOCK_FILE"
        log "Sync process stopped ✓"
    fi

    # Remove the script
    if [[ -f "$SYNC_SCRIPT" ]]; then
        if rm -f "$SYNC_SCRIPT"; then
            log "Theme sync script removed ✓"
        else
            error "Failed to remove theme sync script"
        fi
    fi
}

# Remove installation directory and logs
remove_installation_dir() {
    info "Removing installation directory..."

    if [[ -d "$INSTALL_DIR" ]]; then
        # Show what's in the directory
        local file_count
        file_count=$(find "$INSTALL_DIR" -type f | wc -l)

        if [[ $file_count -gt 0 ]]; then
            info "Directory contains $file_count files"

            if [[ "${FORCE:-false}" != "true" ]]; then
                read -p "Remove installation directory and all logs? (y/N): " -r
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    warn "Keeping installation directory: $INSTALL_DIR"
                    return
                fi
            fi
        fi

        if rm -rf "$INSTALL_DIR"; then
            log "Installation directory removed ✓"
        else
            error "Failed to remove installation directory"
        fi
    fi
}

# Check for Zed dev extension
check_zed_themes() {
    info "Checking for installed Zed themes..."

    local zed_themes_dir="$HOME/.config/zed/themes"

    if [[ -d "$zed_themes_dir" ]]; then
        local theme_count
        theme_count=$(find "$zed_themes_dir" -name "*.json" 2>/dev/null | wc -l)
        if [[ $theme_count -gt 0 ]]; then
            warn "Found $theme_count theme files in Zed themes directory"
            info "Theme files are left in: $zed_themes_dir"
            info "You can remove them manually if desired"
        fi
    else
        log "No Zed themes directory found ✓"
    fi
}

# Clean up any remaining configuration
cleanup_config() {
    info "Cleaning up configuration..."

    # Check if Zed settings were modified
    local zed_settings="$HOME/.config/zed/settings.json"
    if [[ -f "$zed_settings" ]] && grep -q "omazed\|omarchy" "$zed_settings" 2>/dev/null; then
        warn "Zed settings may contain omazed-related themes"
        info "You may want to manually review: $zed_settings"
    fi

    log "Configuration cleanup completed ✓"
}

# Backup important files before removal
create_backup() {
    if [[ "${CREATE_BACKUP:-true}" == "true" ]]; then
        info "Creating backup of configuration files..."

        local backup_dir="$HOME/.local/share/omazed-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup_dir"

        # Backup service file
        if [[ -f "$SERVICE_FILE" ]]; then
            cp "$SERVICE_FILE" "$backup_dir/"
        fi

        # Backup sync script
        if [[ -f "$SYNC_SCRIPT" ]]; then
            cp "$SYNC_SCRIPT" "$backup_dir/"
        fi

        # Backup logs
        if [[ -d "$INSTALL_DIR" ]]; then
            cp -r "$INSTALL_DIR"/* "$backup_dir/" 2>/dev/null || true
        fi

        if [[ -n "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
            log "Backup created at: $backup_dir ✓"
        else
            rmdir "$backup_dir"
            info "No files to backup"
        fi
    fi
}

# Print post-uninstall information
print_completion() {
    cat << EOF

╔═══════════════════════════════════════════════════════════╗
║                  UNINSTALLATION COMPLETE!                ║
╚═══════════════════════════════════════════════════════════╝

🗑️  Omazed has been removed successfully!

📋 WHAT WAS REMOVED:

   ✓ Theme sync script
   ✓ Systemd service
   ✓ Installation directory and logs
   ✓ Service configuration

📝 MANUAL CLEANUP (optional):

   • Remove Zed themes if desired:
     - ~/.config/zed/themes/

   • Review Zed settings if needed:
     - ~/.config/zed/settings.json

🔄 TO REINSTALL:

   Run the install script again:
   ./install.sh

Thanks for using Omazed! 👋

EOF
}

# Error handling
handle_error() {
    error "Uninstallation encountered an error on line $1"
    error "Some components may not have been removed completely"
    exit 1
}

# Main uninstallation function
main() {
    print_banner

    # Parse arguments
    local force=false
    local no_backup=false
    local yes=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                force=true
                FORCE=true
                shift
                ;;
            --no-backup)
                no_backup=true
                CREATE_BACKUP=false
                shift
                ;;
            -y|--yes)
                yes=true
                shift
                ;;
            -h|--help)
                cat << EOF
Omazed Uninstaller - Live theme switching for zed in omarchy

Usage: $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    --force         Force removal without prompts
    --no-backup     Don't create backup of files
    -y, --yes       Answer yes to all prompts

Examples:
    $0              # Interactive uninstallation
    $0 --force      # Force removal of all components
    $0 --no-backup  # Don't create backup files
EOF
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    log "Starting Omazed uninstallation..."

    # Check what's installed
    if ! check_installation; then
        info "Nothing to uninstall. Omazed appears to already be removed."
        exit 0
    fi

    # Confirm uninstallation
    if [[ "$force" != "true" && "$yes" != "true" ]]; then
        echo
        read -p "Are you sure you want to uninstall Omazed? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Uninstallation cancelled by user"
            exit 0
        fi
    fi

    # Create backup if requested
    if [[ "$no_backup" != "true" ]]; then
        create_backup
    fi

    # Remove components
    remove_service
    remove_sync_script
    remove_installation_dir
    check_zed_themes
    cleanup_config

    print_completion

    log "Uninstallation completed successfully! 🗑️"
}

# Set up error handling
trap 'handle_error $LINENO' ERR

# Run main uninstallation
main "$@"
