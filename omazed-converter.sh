#!/bin/bash

# Omazed Converter - Convert Alacritty TOML config to Zed theme JSON

set -euo pipefail

show_usage() {
    echo "Usage: $0 <alacritty_config_file> [theme_name] [output_directory]"
    echo ""
    echo "Convert Alacritty TOML config to Zed theme JSON format"
    echo ""
    echo "Arguments:"
    echo "  alacritty_config_file  Path to Alacritty TOML config file"
    echo "  theme_name            Optional theme name (default: 'Converted <filename>')"
    echo "  output_directory      Optional output directory (default: same as input file)"
    exit 1
}

# Function to normalize hex color (convert 0x prefix to #)
normalize_hex_color() {
    local color="$1"
    if [[ "$color" =~ ^0x ]]; then
        echo "#${color:2}"
    elif [[ "$color" =~ ^# ]]; then
        echo "$color"
    else
        echo "#$color"
    fi
}

hex_to_rgb() {
    local hex="$1"
    hex=$(normalize_hex_color "$hex")
    hex="${hex#\#}"

    local r=$((16#${hex:0:2}))
    local g=$((16#${hex:2:2}))
    local b=$((16#${hex:4:2}))

    echo "$r $g $b"
}

rgb_to_hex() {
    local r="$1" g="$2" b="$3"
    printf "#%02x%02x%02x" "$r" "$g" "$b"
}

lighten_color() {
    local hex="$1"
    local factor="${2:-20}"

    read -r r g b <<< "$(hex_to_rgb "$hex")"

    # Apply lightening formula: r + (255 - r) * factor / 100
    r=$(( r + (255 - r) * factor / 100 ))
    g=$(( g + (255 - g) * factor / 100 ))
    b=$(( b + (255 - b) * factor / 100 ))

    # Clamp to 255
    r=$((r > 255 ? 255 : r))
    g=$((g > 255 ? 255 : g))
    b=$((b > 255 ? 255 : b))

    rgb_to_hex "$r" "$g" "$b"
}

darken_color() {
    local hex="$1"
    local factor="${2:-20}"

    read -r r g b <<< "$(hex_to_rgb "$hex")"

    # Apply darkening formula: r * (100 - factor) / 100
    local multiplier=$((100 - factor))
    r=$((r * multiplier / 100))
    g=$((g * multiplier / 100))
    b=$((b * multiplier / 100))

    # Clamp to 0
    r=$((r < 0 ? 0 : r))
    g=$((g < 0 ? 0 : g))
    b=$((b < 0 ? 0 : b))

    rgb_to_hex "$r" "$g" "$b"
}

# Convert RGB to HSL - returns "hue saturation lightness"
rgb_to_hsl() {
    local hex="$1"
    read -r r g b <<< "$(hex_to_rgb "$hex")"

    # Normalize to 0-1
    local rf=$(awk "BEGIN {printf \"%.6f\", $r/255}")
    local gf=$(awk "BEGIN {printf \"%.6f\", $g/255}")
    local bf=$(awk "BEGIN {printf \"%.6f\", $b/255}")

    # Find max and min
    local max=$(awk "BEGIN {m=$rf; if($gf>m) m=$gf; if($bf>m) m=$bf; print m}")
    local min=$(awk "BEGIN {m=$rf; if($gf<m) m=$gf; if($bf<m) m=$bf; print m}")
    local delta=$(awk "BEGIN {print $max - $min}")

    # Calculate lightness
    local lightness=$(awk "BEGIN {print ($max + $min) / 2}")

    # Calculate saturation
    local saturation=0
    if (( $(awk "BEGIN {print ($delta > 0.001)}") )); then
        saturation=$(awk "BEGIN {print $delta / (1 - sqrt(($lightness * 2 - 1) * ($lightness * 2 - 1)))}")
    fi

    # Calculate hue
    local hue=0
    if (( $(awk "BEGIN {print ($delta > 0.001)}") )); then
        if (( $(awk "BEGIN {print ($max == $rf)}") )); then
            hue=$(awk "BEGIN {h = 60 * ((($gf - $bf) / $delta) % 6); print h}")
        elif (( $(awk "BEGIN {print ($max == $gf)}") )); then
            hue=$(awk "BEGIN {print 60 * ((($bf - $rf) / $delta) + 2)}")
        else
            hue=$(awk "BEGIN {print 60 * ((($rf - $gf) / $delta) + 4)}")
        fi
    fi

    # Normalize to 0-360
    hue=$(awk "BEGIN {h=$hue; while(h<0) h+=360; while(h>=360) h-=360; print h}")

    echo "$hue $saturation $lightness"
}

# Convert RGB to HSL to get hue (0-360)
rgb_to_hue() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"
    printf "%.0f" "$hue"
}

# Convert HSL to RGB
hsl_to_rgb() {
    local h="$1" s="$2" l="$3"

    local c=$(awk "BEGIN {print $s * (1 - sqrt(($l * 2 - 1) * ($l * 2 - 1)))}")
    local x=$(awk "BEGIN {print $c * (1 - sqrt((($h / 60) % 2 - 1) * (($h / 60) % 2 - 1)))}")
    local m=$(awk "BEGIN {print $l - $c / 2}")

    local rf=0 gf=0 bf=0

    if (( $(awk "BEGIN {print ($h >= 0 && $h < 60)}") )); then
        rf=$c; gf=$x; bf=0
    elif (( $(awk "BEGIN {print ($h >= 60 && $h < 120)}") )); then
        rf=$x; gf=$c; bf=0
    elif (( $(awk "BEGIN {print ($h >= 120 && $h < 180)}") )); then
        rf=0; gf=$c; bf=$x
    elif (( $(awk "BEGIN {print ($h >= 180 && $h < 240)}") )); then
        rf=0; gf=$x; bf=$c
    elif (( $(awk "BEGIN {print ($h >= 240 && $h < 300)}") )); then
        rf=$x; gf=0; bf=$c
    else
        rf=$c; gf=0; bf=$x
    fi

    local r=$(awk "BEGIN {printf \"%.0f\", ($rf + $m) * 255}")
    local g=$(awk "BEGIN {printf \"%.0f\", ($gf + $m) * 255}")
    local b=$(awk "BEGIN {printf \"%.0f\", ($bf + $m) * 255}")

    # Clamp values
    r=$((r < 0 ? 0 : r > 255 ? 255 : r))
    g=$((g < 0 ? 0 : g > 255 ? 255 : g))
    b=$((b < 0 ? 0 : b > 255 ? 255 : b))

    rgb_to_hex "$r" "$g" "$b"
}

is_yellow() {
    local hex="$1"
    local hue=$(rgb_to_hue "$hex")
    (( $(awk "BEGIN {print ($hue >= 40 && $hue <= 70)}") ))
}

is_green() {
    local hex="$1"
    local hue=$(rgb_to_hue "$hex")
    (( $(awk "BEGIN {print ($hue >= 80 && $hue <= 160)}") ))
}

is_red() {
    local hex="$1"
    local hue=$(rgb_to_hue "$hex")
    (( $(awk "BEGIN {print ($hue >= 340 || $hue <= 20)}") ))
}

synthesize_yellow() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"

    # Target yellow hue: 55 degrees (middle of yellow range 40-70)
    local target_hue=55

    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.40
    light=$(awk "BEGIN {print ($light > $max_lightness ? $max_lightness : $light)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

synthesize_red() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"

    # Target red hue: 0 degrees (middle of red range 340-20, wrapping around 0)
    local target_hue=0

    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.40
    light=$(awk "BEGIN {print ($light > $max_lightness ? $max_lightness : $light)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

synthesize_green() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"

    # Target green hue: 120 degrees (middle of green range 80-160)
    local target_hue=120

    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.37
    light=$(awk "BEGIN {print ($light > $max_lightness ? $max_lightness : $light)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

validate_yellow() {
    local normal="$1"
    local bright="$2"

    if [[ -n "$normal" ]] && is_yellow "$normal"; then
        echo "$normal"
    elif [[ -n "$normal" ]]; then
        local synthesized=$(synthesize_yellow "$normal")
        local original_hue=$(rgb_to_hue "$normal")
        echo "$synthesized"
    elif [[ -n "$bright" ]] && is_yellow "$bright"; then
        echo "$bright"
    else
        echo "#ffff00"
    fi
}

validate_red() {
    local normal="$1"
    local bright="$2"

    if [[ -n "$normal" ]] && is_red "$normal"; then
        echo "$normal"
    elif [[ -n "$normal" ]]; then
        local synthesized=$(synthesize_red "$normal")
        local original_hue=$(rgb_to_hue "$normal")
        echo "$synthesized"
    elif [[ -n "$bright" ]] && is_red "$bright"; then
        echo "$bright"
    else
        echo "#ff4444"
    fi
}

validate_green() {
    local normal="$1"
    local bright="$2"

    if [[ -n "$normal" ]] && is_green "$normal"; then
        echo "$normal"
    elif [[ -n "$normal" ]]; then
        local synthesized=$(synthesize_green "$normal")
        local original_hue=$(rgb_to_hue "$normal")
        echo "$synthesized"
    elif [[ -n "$bright" ]] && is_green "$bright"; then
        echo "$bright"
    else
        echo "#44ff44"
    fi
}



parse_alacritty_config() {
    local content="$1"

    background=$(echo "$content" | grep -oP 'background\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    foreground=$(echo "$content" | grep -oP 'foreground\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")

    normal_black=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'black\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_red=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'red\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_green=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'green\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_yellow=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'yellow\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_blue=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'blue\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_magenta=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'magenta\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_cyan=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'cyan\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    normal_white=$(echo "$content" | grep -A20 '\[colors\.normal\]' | grep -oP 'white\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")

    bright_black=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'black\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_red=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'red\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_green=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'green\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_yellow=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'yellow\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_blue=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'blue\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_magenta=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'magenta\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_cyan=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'cyan\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    bright_white=$(echo "$content" | grep -A20 '\[colors\.bright\]' | grep -oP 'white\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")

    [[ -n "$background" ]] && background=$(normalize_hex_color "$background")
    [[ -n "$foreground" ]] && foreground=$(normalize_hex_color "$foreground")
    [[ -n "$normal_black" ]] && normal_black=$(normalize_hex_color "$normal_black")
    [[ -n "$normal_red" ]] && normal_red=$(normalize_hex_color "$normal_red")
    [[ -n "$normal_green" ]] && normal_green=$(normalize_hex_color "$normal_green")
    [[ -n "$normal_yellow" ]] && normal_yellow=$(normalize_hex_color "$normal_yellow")
    [[ -n "$normal_blue" ]] && normal_blue=$(normalize_hex_color "$normal_blue")
    [[ -n "$normal_magenta" ]] && normal_magenta=$(normalize_hex_color "$normal_magenta")
    [[ -n "$normal_cyan" ]] && normal_cyan=$(normalize_hex_color "$normal_cyan")
    [[ -n "$normal_white" ]] && normal_white=$(normalize_hex_color "$normal_white")
    [[ -n "$bright_black" ]] && bright_black=$(normalize_hex_color "$bright_black")
    [[ -n "$bright_red" ]] && bright_red=$(normalize_hex_color "$bright_red")
    [[ -n "$bright_green" ]] && bright_green=$(normalize_hex_color "$bright_green")
    [[ -n "$bright_yellow" ]] && bright_yellow=$(normalize_hex_color "$bright_yellow")
    [[ -n "$bright_blue" ]] && bright_blue=$(normalize_hex_color "$bright_blue")
    [[ -n "$bright_magenta" ]] && bright_magenta=$(normalize_hex_color "$bright_magenta")
    [[ -n "$bright_cyan" ]] && bright_cyan=$(normalize_hex_color "$bright_cyan")
    [[ -n "$bright_white" ]] && bright_white=$(normalize_hex_color "$bright_white")
}

get_color() {
    local primary="$1"
    local fallback="$2"
    local default="$3"

    if [[ -n "$primary" ]]; then
        echo "$primary"
    elif [[ -n "$fallback" ]]; then
        echo "$fallback"
    else
        echo "$default"
    fi
}

create_zed_theme() {
    local theme_name="$1"
    local author="${2:-Converted}"

    local bg="${background:-#000000}"
    local fg="${foreground:-#ffffff}"

    local darker_bg=$(darken_color "$bg" 30)
    local lighter_bg=$(lighten_color "$bg" 10)
    local much_lighter_bg=$(lighten_color "$bg" 20)
    local muted_fg=$(darken_color "$fg" 40)

    local blue=$(get_color "$normal_blue" "$bright_blue" "#0099ff")
    local red=$(get_color "$normal_red" "$bright_red" "#ff4444")
    local green=$(get_color "$normal_green" "$bright_green" "#44ff44")
    local yellow=$(get_color "$normal_yellow" "$bright_yellow" "#ffff44")

    local ensured_yellow=$(validate_yellow "$normal_yellow" "$bright_yellow")
    local ensured_red=$(validate_red "$normal_red" "$bright_red" )
    local ensured_green=$(validate_green "$normal_green" "$bright_green")

    local magenta=$(get_color "$normal_magenta" "$bright_magenta" "#ff44ff")
    local cyan=$(get_color "$normal_cyan" "$bright_cyan" "#44ffff")

    local ansi_black="${normal_black:-#000000}"
    local ansi_bright_black="${bright_black:-${normal_black:-#555555}}"
    local ansi_white="${normal_white:-$fg}"
    local ansi_bright_white="${bright_white:-${normal_white:-$fg}}"
    local ansi_bright_red="${bright_red:-$red}"
    local ansi_bright_green="${bright_green:-$green}"
    local ansi_bright_yellow="${bright_yellow:-$yellow}"
    local ansi_bright_blue="${bright_blue:-$blue}"
    local ansi_bright_magenta="${bright_magenta:-$magenta}"
    local ansi_bright_cyan="${bright_cyan:-$cyan}"

    cat << EOF
{
  "\$schema": "https://zed.dev/schema/themes/v0.2.0.json",
  "name": "$theme_name",
  "author": "$author",
  "themes": [
    {
      "name": "$theme_name",
      "appearance": "dark",
      "style": {
        "background": "$bg",
        "foreground": "$fg",
        "border": "$darker_bg",
        "border.variant": "$lighter_bg",
        "border.focused": "$blue",
        "border.selected": "$blue",
        "border.transparent": "#00000000",
        "border.disabled": "$lighter_bg",
        "elevated_surface.background": "$darker_bg",
        "surface.background": "$bg",
        "drop_target.background": "${lighter_bg}80",
        "element.background": "$bg",
        "element.hover": "$lighter_bg",
        "element.active": "${blue}4d",
        "element.selected": "${lighter_bg}4d",
        "element.disabled": "$muted_fg",
        "ghost_element.background": "#00000000",
        "ghost_element.hover": "$lighter_bg",
        "ghost_element.active": "${blue}99",
        "ghost_element.selected": "${blue}66",
        "ghost_element.disabled": "$lighter_bg",
        "text": "$fg",
        "text.muted": "$muted_fg",
        "text.placeholder": "$muted_fg",
        "text.disabled": "$muted_fg",
        "text.accent": "$blue",
        "icon": "$fg",
        "icon.muted": "$muted_fg",
        "icon.disabled": "$muted_fg",
        "icon.placeholder": "$muted_fg",
        "icon.accent": "$blue",
        "status_bar.background": "$darker_bg",
        "title_bar.background": "$darker_bg",
        "toolbar.background": "$bg",
        "tab_bar.background": "$darker_bg",
        "tab.inactive_background": "$darker_bg",
        "tab.active_background": "$bg",
        "search.match_background": "$lighter_bg",
        "panel.background": "$darker_bg",
        "panel.focused_border": "$blue",
        "pane.focused_border": "$blue",
        "scrollbar.thumb.background": "${lighter_bg}88",
        "scrollbar.thumb.hover_background": "$much_lighter_bg",
        "scrollbar.thumb.border": "${lighter_bg}44",
        "scrollbar.track.background": "$darker_bg",
        "scrollbar.track.border": "$(darken_color "$darker_bg" 20)",
        "editor.foreground": "$fg",
        "editor.background": "$bg",
        "editor.gutter.background": "$bg",
        "editor.subheader.background": "$darker_bg",
        "editor.active_line.background": "$lighter_bg",
        "editor.highlighted_line.background": "$lighter_bg",
        "editor.line_number": "$muted_fg",
        "editor.active_line_number": "$fg",
        "editor.invisible": "$muted_fg",
        "editor.wrap_guide": "$lighter_bg",
        "editor.active_wrap_guide": "$muted_fg",
        "editor.document_highlight.read_background": "${muted_fg}35",
        "editor.document_highlight.write_background": "${muted_fg}35",
        "terminal.background": "$bg",
        "terminal.foreground": "$fg",
        "terminal.bright_foreground": "$fg",
        "terminal.dim_foreground": "$fg",
        "terminal.ansi.black": "$ansi_black",
        "terminal.ansi.bright_black": "$ansi_bright_black",
        "terminal.ansi.dim_black": "$ansi_black",
        "terminal.ansi.red": "$red",
        "terminal.ansi.bright_red": "$ansi_bright_red",
        "terminal.ansi.dim_red": "$red",
        "terminal.ansi.green": "$green",
        "terminal.ansi.bright_green": "$ansi_bright_green",
        "terminal.ansi.dim_green": "$green",
        "terminal.ansi.yellow": "$yellow",
        "terminal.ansi.bright_yellow": "$ansi_bright_yellow",
        "terminal.ansi.dim_yellow": "$yellow",
        "terminal.ansi.blue": "$blue",
        "terminal.ansi.bright_blue": "$ansi_bright_blue",
        "terminal.ansi.dim_blue": "$blue",
        "terminal.ansi.magenta": "$magenta",
        "terminal.ansi.bright_magenta": "$ansi_bright_magenta",
        "terminal.ansi.dim_magenta": "$magenta",
        "terminal.ansi.cyan": "$cyan",
        "terminal.ansi.bright_cyan": "$ansi_bright_cyan",
        "terminal.ansi.dim_cyan": "$cyan",
        "terminal.ansi.white": "$ansi_white",
        "terminal.ansi.bright_white": "$ansi_bright_white",
        "terminal.ansi.dim_white": "$ansi_white",
        "link_text.hover": "$blue",
        "conflict": "$ensured_yellow",
        "conflict.background": "${ensured_yellow}20",
        "conflict.border": "$ensured_yellow",
        "created": "$ensured_green",
        "created.background": "${ensured_green}20",
        "created.border": "$ensured_green",
        "deleted": "$ensured_red",
        "deleted.background": "${ensured_red}20",
        "deleted.border": "$ensured_red",
        "error": "$ensured_red",
        "error.background": "${ensured_red}20",
        "error.border": "$ensured_red",
        "hidden": "$muted_fg",
        "hidden.background": "$bg",
        "hidden.border": "$lighter_bg",
        "hint": "$muted_fg",
        "hint.background": "${blue}20",
        "hint.border": "$blue",
        "ignored": "$muted_fg",
        "ignored.background": "$bg",
        "ignored.border": "$lighter_bg",
        "info": "$blue",
        "info.background": "${blue}20",
        "info.border": "$blue",
        "modified": "$ensured_yellow",
        "modified.background": "${ensured_yellow}20",
        "modified.border": "$ensured_yellow",
        "predictive": "$muted_fg",
        "predictive.background": "${muted_fg}20",
        "predictive.border": "$muted_fg",
        "renamed": "$blue",
        "renamed.background": "${blue}20",
        "renamed.border": "$blue",
        "success": "$ensured_green",
        "success.background": "${ensured_green}20",
        "success.border": "$ensured_green",
        "unreachable": "$muted_fg",
        "unreachable.background": "$bg",
        "unreachable.border": "$lighter_bg",
        "warning": "$ensured_yellow",
        "warning.background": "${ensured_yellow}20",
        "warning.border": "$ensured_yellow",
        "players": [
          {
            "cursor": "$blue",
            "background": "$blue",
            "selection": "${blue}33"
          },
          {
            "cursor": "$magenta",
            "background": "$magenta",
            "selection": "${magenta}33"
          },
          {
            "cursor": "$cyan",
            "background": "$cyan",
            "selection": "${cyan}33"
          },
          {
            "cursor": "$green",
            "background": "$green",
            "selection": "${green}33"
          }
        ],
        "version_control.added": "$ensured_green",
        "version_control.added_background": "${ensured_green}20",
        "version_control.deleted": "$ensured_red",
        "version_control.deleted_background": "${ensured_red}20",
        "version_control.modified": "$ensured_yellow",
        "version_control.modified_background": "${ensured_yellow}20",

        "syntax": {
          "attribute": {
            "color": "$yellow",
            "font_style": null,
            "font_weight": null
          },
          "boolean": {
            "color": "$red",
            "font_style": null,
            "font_weight": null
          },
          "comment": {
            "color": "$muted_fg",
            "font_style": "italic",
            "font_weight": null
          },
          "comment.doc": {
            "color": "$muted_fg",
            "font_style": "italic",
            "font_weight": null
          },
          "constant": {
            "color": "$red",
            "font_style": null,
            "font_weight": null
          },
          "constructor": {
            "color": "$magenta",
            "font_style": null,
            "font_weight": null
          },
          "embedded": {
            "color": "$fg",
            "font_style": null,
            "font_weight": null
          },
          "emphasis": {
            "color": "$red",
            "font_style": "italic",
            "font_weight": null
          },
          "emphasis.strong": {
            "color": "$red",
            "font_style": null,
            "font_weight": 700
          },
          "enum": {
            "color": "$cyan",
            "font_style": null,
            "font_weight": null
          },
          "function": {
            "color": "$blue",
            "font_style": null,
            "font_weight": null
          },
          "hint": {
            "color": "$cyan",
            "font_style": null,
            "font_weight": 700
          },
          "keyword": {
            "color": "$magenta",
            "font_style": null,
            "font_weight": null
          },
          "label": {
            "color": "$blue",
            "font_style": null,
            "font_weight": null
          },
          "link_text": {
            "color": "$blue",
            "font_style": "italic",
            "font_weight": null
          },
          "link_uri": {
            "color": "$magenta",
            "font_style": null,
            "font_weight": null
          },
          "number": {
            "color": "$red",
            "font_style": null,
            "font_weight": null
          },
          "operator": {
            "color": "$cyan",
            "font_style": null,
            "font_weight": null
          },
          "predictive": {
            "color": "$muted_fg",
            "font_style": "italic",
            "font_weight": null
          },
          "preproc": {
            "color": "$fg",
            "font_style": null,
            "font_weight": null
          },
          "primary": {
            "color": "$fg",
            "font_style": null,
            "font_weight": null
          },
          "property": {
            "color": "$blue",
            "font_style": null,
            "font_weight": null
          },
          "punctuation": {
            "color": "$muted_fg",
            "font_style": null,
            "font_weight": null
          },
          "punctuation.bracket": {
            "color": "$muted_fg",
            "font_style": null,
            "font_weight": null
          },
          "punctuation.delimiter": {
            "color": "$muted_fg",
            "font_style": null,
            "font_weight": null
          },
          "punctuation.list_marker": {
            "color": "$muted_fg",
            "font_style": null,
            "font_weight": null
          },
          "punctuation.special": {
            "color": "$cyan",
            "font_style": null,
            "font_weight": null
          },
          "string": {
            "color": "$green",
            "font_style": null,
            "font_weight": null
          },
          "string.escape": {
            "color": "$magenta",
            "font_style": null,
            "font_weight": null
          },
          "string.regex": {
            "color": "$cyan",
            "font_style": null,
            "font_weight": null
          },
          "string.special": {
            "color": "$magenta",
            "font_style": null,
            "font_weight": null
          },
          "string.special.symbol": {
            "color": "$green",
            "font_style": null,
            "font_weight": null
          },
          "tag": {
            "color": "$blue",
            "font_style": null,
            "font_weight": null
          },
          "text.literal": {
            "color": "$green",
            "font_style": null,
            "font_weight": null
          },
          "title": {
            "color": "$blue",
            "font_style": null,
            "font_weight": 700
          },
          "type": {
            "color": "$yellow",
            "font_style": null,
            "font_weight": null
          },
          "variable": {
            "color": "$fg",
            "font_style": null,
            "font_weight": null
          },
          "variable.special": {
            "color": "$red",
            "font_style": null,
            "font_weight": null
          },
          "variant": {
            "color": "$blue",
            "font_style": null,
            "font_weight": null
          }
        }
      }
    }
  ]
}
EOF
}

main() {
    if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
        show_usage
    fi

    if [[ $# -lt 1 || $# -gt 3 ]]; then
        show_usage
    fi

    local input_file="$1"
    local theme_name="${2:-}"
    local output_dir="${3:-}"

    if [[ ! -f "$input_file" ]]; then
        echo "Error: File $input_file not found" >&2
        exit 1
    fi

    if [[ -z "$theme_name" ]]; then
        local basename=$(basename "$input_file")
        theme_name="Converted ${basename%.*}"
    fi

    if [[ -z "$output_dir" ]]; then
        output_dir="$(dirname "$input_file")"
    fi

    local content
    if ! content=$(cat "$input_file"); then
        echo "Error: Could not read file $input_file" >&2
        exit 1
    fi

    parse_alacritty_config "$content"

    if [[ -z "$background" && -z "$foreground" && -z "$normal_red" && -z "$normal_green" && -z "$normal_blue" ]]; then
        echo "Warning: No colors found in the config file" >&2
        exit 1
    fi

    mkdir -p "$output_dir"

    local output_filename
    output_filename="$(echo "$theme_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-').json"
    local output_file="$output_dir/$output_filename"

    # Create the theme and write to file
    create_zed_theme "$theme_name" "Converted" > "$output_file"

    echo "Converted theme saved to: $output_file"
    echo "Theme name: $theme_name"
    echo ""
    echo "Extracted colors:"
    [[ -n "$background" ]] && echo "  background: $background"
    [[ -n "$foreground" ]] && echo "  foreground: $foreground"
    [[ -n "$normal_black" ]] && echo "  normal_black: $normal_black"
    [[ -n "$normal_red" ]] && echo "  normal_red: $normal_red"
    [[ -n "$normal_green" ]] && echo "  normal_green: $normal_green"
    [[ -n "$normal_yellow" ]] && echo "  normal_yellow: $normal_yellow"
    [[ -n "$normal_blue" ]] && echo "  normal_blue: $normal_blue"
    [[ -n "$normal_magenta" ]] && echo "  normal_magenta: $normal_magenta"
    [[ -n "$normal_cyan" ]] && echo "  normal_cyan: $normal_cyan"
    [[ -n "$normal_white" ]] && echo "  normal_white: $normal_white"
    [[ -n "$bright_black" ]] && echo "  bright_black: $bright_black"
    [[ -n "$bright_red" ]] && echo "  bright_red: $bright_red"
    [[ -n "$bright_green" ]] && echo "  bright_green: $bright_green"
    [[ -n "$bright_yellow" ]] && echo "  bright_yellow: $bright_yellow"
    [[ -n "$bright_blue" ]] && echo "  bright_blue: $bright_blue"
    [[ -n "$bright_magenta" ]] && echo "  bright_magenta: $bright_magenta"
    [[ -n "$bright_cyan" ]] && echo "  bright_cyan: $bright_cyan"
    [[ -n "$bright_white" ]] && echo "  bright_white: $bright_white"
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
