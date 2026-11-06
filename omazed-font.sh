#!/bin/bash

set -euo pipefail

ZED_CONFIG_DIR="$HOME/.config/zed"
ZED_SETTINGS_PATH="$ZED_CONFIG_DIR/settings.json"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}ℹ${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

get_current_font() {
    local state_font="$HOME/.local/state/omarchy/current/font.txt"
    if [[ -f "$state_font" ]]; then
        cat "$state_font"
        return 0
    fi

    local font=""
    if command -v omarchy >/dev/null 2>&1; then
        font=$(omarchy font current 2>/dev/null || true)
    fi

    if [[ -z "$font" ]] && command -v fc-match >/dev/null 2>&1; then
        font=$(fc-match monospace -f '%{family}\n' 2>/dev/null | head -n1 | cut -d, -f1)
    fi

    printf '%s\n' "$font"
}

set_zed_font() {
    local font_name="$1"

    if [[ -z "$font_name" ]]; then
        error "No font name provided"
        return 1
    fi

    if [[ "$font_name" == *'"'* || "$font_name" == *'\\'* ]]; then
        error "Unsupported character in font name: $font_name"
        return 1
    fi

    mkdir -p "$ZED_CONFIG_DIR"
    if [[ ! -f "$ZED_SETTINGS_PATH" ]]; then
        echo "{}" > "$ZED_SETTINGS_PATH"
    fi

    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required for parsing Zed settings. Please install jq."
        return 1
    fi

    local temp_file clean_file
    temp_file=$(mktemp)
    clean_file=$(mktemp)

    # Zed writes // comments and trailing commas which jq rejects — strip both.
    # The (*SKIP)(*F) guard keeps // inside quoted strings intact.
    perl -0777 -pe 's/"(?:[^"\\]|\\.)*"(*SKIP)(*F)|\/\/[^\n]*//g; s/,([\t \n]*[}\]])/\1/g' "$ZED_SETTINGS_PATH" > "$clean_file"

    if ! jq --arg font "$font_name" '
      .buffer_font_family = $font
    ' "$clean_file" > "$temp_file" 2>/dev/null; then
        error "Failed to parse or update Zed settings.json"
        rm -f "$temp_file" "$clean_file"
        return 1
    fi

    cat "$temp_file" > "$ZED_SETTINGS_PATH"
    rm -f "$temp_file" "$clean_file"
    
    success "Zed editor font set to: $font_name"
}

main() {
    local current_font="${1:-}"
    if [[ -z "$current_font" ]]; then
        current_font=$(get_current_font)
    fi

    if [[ -z "$current_font" ]]; then
        warn "Could not determine current Omarchy font"
        return 1
    fi

    set_zed_font "$current_font"
}

main "$@"
