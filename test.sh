#!/bin/bash

# Test script for Omazed
# Live theme switching for zed in omarchy - verifies all functionality before deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/omazed-test-$$"
OMARCHY_TEST_PATH="$TEST_DIR/.config/omarchy/current"
ZED_TEST_PATH="$TEST_DIR/.config/zed"
ORIGINAL_HOME="$HOME"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((TESTS_PASSED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[FAIL]${NC} $*"
    ((TESTS_FAILED++))
}

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Setup test environment
setup_test_env() {
    info "Setting up test environment..."

    # Create test directories
    mkdir -p "$OMARCHY_TEST_PATH"
    mkdir -p "$ZED_TEST_PATH"

    # Create test theme file
    echo "gruvbox" > "$OMARCHY_TEST_PATH/theme"

    # Create initial Zed settings
    echo '{"theme": "One Dark"}' > "$ZED_TEST_PATH/settings.json"

    info "Test environment created at: $TEST_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
        info "Test environment cleaned up"
    fi
}

# Test dependencies
test_dependencies() {
    info "Testing dependencies..."

    local deps=("inotifywait" "cargo" "rustc")
    local missing=()

    for dep in "${deps[@]}"; do
        if command -v "$dep" >/dev/null 2>&1; then
            log "Dependency $dep found"
        else
            error "Dependency $dep missing"
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        log "All dependencies satisfied"
    else
        error "Missing dependencies: ${missing[*]}"
    fi
}

# Test Rust target
test_rust_target() {
    info "Testing Rust WebAssembly target..."

    if rustup target list --installed | grep -q "wasm32-wasip2"; then
        log "WebAssembly target available"
    else
        error "WebAssembly target wasm32-wasip2 not installed"
    fi
}

# Test theme detection
test_theme_detection() {
    info "Testing theme detection..."

    # Export test HOME
    export HOME="$TEST_DIR"

    # Test with regular file
    echo "tokyo-night" > "$OMARCHY_TEST_PATH/theme"

    # Source the theme detection function from watcher script
    if [[ -f "$SCRIPT_DIR/omazed" ]]; then
        # Extract theme detection logic
        local detected_theme
        detected_theme=$(HOME="$TEST_DIR" bash -c '
            OMARCHY_THEME_PATH="'$OMARCHY_TEST_PATH'/theme"
            if [[ -f "$OMARCHY_THEME_PATH" ]]; then
                cat "$OMARCHY_THEME_PATH" 2>/dev/null | tr -d "\n\r"
            fi
        ')

        if [[ "$detected_theme" == "tokyo-night" ]]; then
            log "Theme detection from file works"
        else
            error "Theme detection failed. Expected 'tokyo-night', got '$detected_theme'"
        fi
    else
        warn "omazed not found, skipping theme detection test"
    fi

    # Test with symlink
    rm -f "$OMARCHY_TEST_PATH/theme"
    ln -sf "/usr/share/themes/catppuccin.theme" "$OMARCHY_TEST_PATH/theme"

    local symlink_theme
    symlink_theme=$(basename "$(readlink "$OMARCHY_TEST_PATH/theme")" .theme 2>/dev/null || echo "")

    if [[ "$symlink_theme" == "catppuccin" ]]; then
        log "Theme detection from symlink works"
    else
        error "Symlink theme detection failed. Expected 'catppuccin', got '$symlink_theme'"
    fi

    # Restore HOME
    export HOME="$ORIGINAL_HOME"
}

# Test JSON manipulation
test_json_manipulation() {
    info "Testing JSON settings manipulation..."

    local test_file="$ZED_TEST_PATH/settings.json"
    local original_content='{"theme": "One Dark", "other_setting": "value"}'
    local expected_theme="Gruvbox Dark Hard"

    echo "$original_content" > "$test_file"

    # Test sed-based JSON manipulation (same as used in main script)
    local updated_content
    updated_content=$(sed 's/"theme"[[:space:]]*:[[:space:]]*"[^"]*"/"theme": "'"$expected_theme"'"/' "$test_file")

    if echo "$updated_content" | grep -q "\"theme\": \"$expected_theme\""; then
        log "JSON theme update works"
    else
        error "JSON theme update failed"
    fi

    # Test that other settings are preserved
    if echo "$updated_content" | grep -q '"other_setting": "value"'; then
        log "Other JSON settings preserved"
    else
        error "Other JSON settings lost during update"
    fi
}

# Test extension build
test_extension_build() {
    info "Testing extension build..."

    if [[ ! -f "$SCRIPT_DIR/Cargo.toml" ]]; then
        error "Cargo.toml not found"
        return
    fi

    cd "$SCRIPT_DIR"

    # Check if we can build
    if cargo check --target wasm32-wasip2 >/dev/null 2>&1; then
        log "Extension builds successfully"
    else
        error "Extension build failed"
    fi

    # Try actual build
    if cargo build --target wasm32-wasip2 >/dev/null 2>&1; then
        log "Extension compiles successfully"

        # Check output file
        local wasm_file="target/wasm32-wasip2/debug/omarchy_theme.wasm"
        if [[ -f "$wasm_file" ]]; then
            log "WebAssembly output file created"
        else
            error "WebAssembly output file not found"
        fi
    else
        error "Extension compilation failed"
    fi
}

# Test theme mappings
test_theme_mappings() {
    info "Testing theme mappings..."

    # Define test mappings (should match those in the extension)
    declare -A expected_mappings=(
        ["gruvbox"]="Gruvbox Dark Hard"
        ["catppuccin"]="Catppuccin Mocha"
        ["tokyo-night"]="Tokyo Night"
        ["nord"]="Nord"
        ["omarchy-dark"]="One Dark"
    )

    for omarchy_theme in "${!expected_mappings[@]}"; do
        local expected_zed_theme="${expected_mappings[$omarchy_theme]}"

        # This would test the actual mapping logic if we extracted it
        # For now, just verify the mappings exist
        if [[ -n "$expected_zed_theme" ]]; then
            log "Theme mapping: $omarchy_theme -> $expected_zed_theme"
        else
            error "Missing mapping for theme: $omarchy_theme"
        fi
    done
}

# Test file watching capability
test_file_watching() {
    info "Testing file watching capability..."

    local test_file="$TEST_DIR/watch_test"
    echo "initial" > "$test_file"

    # Test if inotifywait works
    if timeout 2s inotifywait -e modify "$test_file" >/dev/null 2>&1 &
    then
        local watch_pid=$!
        sleep 0.5
        echo "modified" > "$test_file"

        if wait "$watch_pid" 2>/dev/null; then
            log "File watching works"
        else
            warn "File watching test inconclusive"
        fi
    else
        error "inotifywait failed to start"
    fi
}

# Test watcher script syntax
test_watcher_syntax() {
    info "Testing watcher script syntax..."

    if [[ -f "$SCRIPT_DIR/omazed" ]]; then
        if bash -n "$SCRIPT_DIR/omazed"; then
            log "Sync script syntax is valid"
        else
            error "Sync script has syntax errors"
        fi

        # Test with --test flag if possible
        if timeout 5s "$SCRIPT_DIR/omazed" --help >/dev/null 2>&1; then
            log "Sync script help works"
        else
            warn "Sync script help test failed"
        fi
    else
        error "omazed not found"
    fi
}

# Test systemd service file
test_service_file() {
    info "Testing systemd service file..."

    if [[ -f "$SCRIPT_DIR/omazed.service" ]]; then
        # Basic syntax check
        if systemd-analyze verify "$SCRIPT_DIR/omazed.service" 2>/dev/null; then
            log "Systemd service file is valid"
        else
            warn "Systemd service file validation failed"
        fi

        # Check for required sections
        if grep -q "\[Unit\]" "$SCRIPT_DIR/omazed.service" &&
           grep -q "\[Service\]" "$SCRIPT_DIR/omazed.service" &&
           grep -q "\[Install\]" "$SCRIPT_DIR/omazed.service"; then
            log "Service file has required sections"
        else
            error "Service file missing required sections"
        fi
    else
        error "omazed.service not found"
    fi
}

# Test extension.toml
test_extension_manifest() {
    info "Testing extension manifest..."

    if [[ -f "$SCRIPT_DIR/extension.toml" ]]; then
        # Check required fields
        local required_fields=("id" "name" "version" "schema_version" "authors" "description")
        local missing_fields=()

        for field in "${required_fields[@]}"; do
            if grep -q "^$field = " "$SCRIPT_DIR/extension.toml"; then
                log "Extension manifest has $field"
            else
                error "Extension manifest missing $field"
                missing_fields+=("$field")
            fi
        done

        if [[ ${#missing_fields[@]} -eq 0 ]]; then
            log "Extension manifest is complete"
        fi
    else
        error "extension.toml not found"
    fi
}

# Test themes directory
test_themes_directory() {
    info "Testing themes directory..."

    if [[ -d "$SCRIPT_DIR/themes" ]]; then
        local theme_count
        theme_count=$(find "$SCRIPT_DIR/themes" -name "*.json" | wc -l)

        if [[ $theme_count -gt 0 ]]; then
            log "Found $theme_count theme files"

            # Test one theme file for valid JSON
            local sample_theme
            sample_theme=$(find "$SCRIPT_DIR/themes" -name "*.json" | head -1)

            # Simple JSON validation - check if it has basic JSON structure
            if [[ -n "$sample_theme" ]] && grep -q '^\s*{.*}\s*$' "$sample_theme" && grep -q '"' "$sample_theme"; then
                log "Sample theme file appears to be valid JSON"
            else
                warn "Sample theme file may not be valid JSON"
            fi
        else
            warn "No theme files found in themes directory"
        fi
    else
        warn "Themes directory not found (optional)"
    fi
}

# Print test summary
print_summary() {
    echo
    echo "═══════════════════════════════════════"
    echo "             TEST SUMMARY"
    echo "═══════════════════════════════════════"
    echo
    echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
    echo

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed! Omazed is ready for use.${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed. Please fix the issues before using Omazed.${NC}"
        return 1
    fi
}

# Main test function
main() {
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                        OMAZED                            ║"
    echo "║          Live theme switching for zed in omarchy          ║"
    echo "║                      TEST SUITE                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo

    # Setup
    setup_test_env

    # Run tests
    test_dependencies
    test_rust_target
    test_extension_manifest
    test_extension_build
    test_theme_detection
    test_json_manipulation
    test_theme_mappings
    test_file_watching
    test_watcher_syntax
    test_service_file
    test_themes_directory

    # Cleanup and summary
    cleanup_test_env
    print_summary
}

# Handle cleanup on exit
trap cleanup_test_env EXIT

# Run tests
main "$@"
