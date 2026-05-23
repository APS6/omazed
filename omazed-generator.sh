#!/bin/bash

# Omazed Generator - Convert Omarchy colors.toml (or Alacritty TOML) to Zed theme JSON

set -euo pipefail

show_usage() {
    echo "Usage: $0 <colors_toml_or_alacritty_file> [output_directory] [template_file] [appearance]"
    echo ""
    echo "Generate Omazed Zed theme JSON"
    echo ""
    echo "Arguments:"
    echo "  colors_toml_or_alacritty_file  Path to colors.toml or alacritty.toml file"
    echo "  output_directory               Optional output directory (default: same as input file)"
    echo "  template_file                  Optional template path (default: alongside generator)"
    echo "  appearance                     Optional appearance (light or dark, default: dark)"
    exit 1
}

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

    r=$(( r + (255 - r) * factor / 100 ))
    g=$(( g + (255 - g) * factor / 100 ))
    b=$(( b + (255 - b) * factor / 100 ))

    r=$((r > 255 ? 255 : r))
    g=$((g > 255 ? 255 : g))
    b=$((b > 255 ? 255 : b))

    rgb_to_hex "$r" "$g" "$b"
}

darken_color() {
    local hex="$1"
    local factor="${2:-20}"

    read -r r g b <<< "$(hex_to_rgb "$hex")"

    local multiplier=$((100 - factor))
    r=$((r * multiplier / 100))
    g=$((g * multiplier / 100))
    b=$((b * multiplier / 100))

    r=$((r < 0 ? 0 : r))
    g=$((g < 0 ? 0 : g))
    b=$((b < 0 ? 0 : b))

    rgb_to_hex "$r" "$g" "$b"
}

apply_alpha() {
    local hex="$1"
    local percent="$2"
    local alpha

    alpha=$((255 * percent / 100))
    printf "%s%02x" "$hex" "$alpha"
}

escape_sed() {
    local value="$1"
    value=${value//\\/\\\\}
    value=${value//&/\\&}
    value=${value//|/\\|}
    echo "$value"
}

rgb_to_hsl() {
    local hex="$1"
    read -r r g b <<< "$(hex_to_rgb "$hex")"

    local rf=$(awk "BEGIN {printf \"%.6f\", $r/255}")
    local gf=$(awk "BEGIN {printf \"%.6f\", $g/255}")
    local bf=$(awk "BEGIN {printf \"%.6f\", $b/255}")

    local max=$(awk "BEGIN {m=$rf; if($gf>m) m=$gf; if($bf>m) m=$bf; print m}")
    local min=$(awk "BEGIN {m=$rf; if($gf<m) m=$gf; if($bf<m) m=$bf; print m}")
    local delta=$(awk "BEGIN {print $max - $min}")

    local lightness=$(awk "BEGIN {print ($max + $min) / 2}")

    local saturation=0
    if (( $(awk "BEGIN {print ($delta > 0.001)}") )); then
        saturation=$(awk "BEGIN {print $delta / (1 - sqrt(($lightness * 2 - 1) * ($lightness * 2 - 1)))}")
    fi

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

    hue=$(awk "BEGIN {h=$hue; while(h<0) h+=360; while(h>=360) h-=360; print h}")

    echo "$hue $saturation $lightness"
}

rgb_to_hue() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"
    printf "%.0f" "$hue"
}

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

    local target_hue=55
    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.40
    light=$(awk "BEGIN {print ($light > $max_lightness ? $light : $max_lightness)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

synthesize_red() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"

    local target_hue=0
    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.40
    light=$(awk "BEGIN {print ($light > $max_lightness ? $light : $max_lightness)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

synthesize_green() {
    local hex="$1"
    read -r hue sat light <<< "$(rgb_to_hsl "$hex")"

    local target_hue=120
    local min_saturation=0.4
    sat=$(awk "BEGIN {print ($sat > $min_saturation ? $sat : $min_saturation)}")

    local max_lightness=0.37
    light=$(awk "BEGIN {print ($light > $max_lightness ? $light : $max_lightness)}")

    hsl_to_rgb "$target_hue" "$sat" "$light"
}

validate_yellow() {
    local normal="$1"
    local bright="$2"

    if [[ -n "$normal" ]] && is_yellow "$normal"; then
        echo "$normal"
    elif [[ -n "$normal" ]]; then
        local synthesized
        synthesized=$(synthesize_yellow "$normal")
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
        local synthesized
        synthesized=$(synthesize_red "$normal")
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
        local synthesized
        synthesized=$(synthesize_green "$normal")
        echo "$synthesized"
    elif [[ -n "$bright" ]] && is_green "$bright"; then
        echo "$bright"
    else
        echo "#44ff44"
    fi
}

parse_colors_toml() {
    local file_path="$1"

    while IFS='=' read -r key value; do
        key=${key#"${key%%[![:space:]]*}"}
        key=${key%"${key##*[![:space:]]}"}
        value=${value#"${value%%[![:space:]]*}"}
        value=${value%"${value##*[![:space:]]}"}
        if [[ -z "$key" || "$key" == \#* ]]; then
            continue
        fi
        value=${value%\"}
        value=${value#\"}
        value=${value%\'}
        value=${value#\'}
        [[ -n "$value" ]] && value=$(normalize_hex_color "$value")

        case "$key" in
            accent) accent="$value" ;;
            cursor) cursor="$value" ;;
            foreground) foreground="$value" ;;
            background) background="$value" ;;
            selection_foreground) selection_foreground="$value" ;;
            selection_background) selection_background="$value" ;;
            color0) color0="$value" ;;
            color1) color1="$value" ;;
            color2) color2="$value" ;;
            color3) color3="$value" ;;
            color4) color4="$value" ;;
            color5) color5="$value" ;;
            color6) color6="$value" ;;
            color7) color7="$value" ;;
            color8) color8="$value" ;;
            color9) color9="$value" ;;
            color10) color10="$value" ;;
            color11) color11="$value" ;;
            color12) color12="$value" ;;
            color13) color13="$value" ;;
            color14) color14="$value" ;;
            color15) color15="$value" ;;
        esac
    done < "$file_path"
}

parse_alacritty_toml() {
    local file_path="$1"

    local content
    content=$(cat "$file_path")

    background=$(echo "$content" | grep -oP 'background\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")
    foreground=$(echo "$content" | grep -oP 'foreground\s*=\s*["\'\'']*\K(?:0x|#)?[0-9a-fA-F]+' | head -1 || echo "")

    local normal_black normal_red normal_green normal_yellow normal_blue normal_magenta normal_cyan normal_white
    local bright_black bright_red bright_green bright_yellow bright_blue bright_magenta bright_cyan bright_white

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

    [[ -n "$normal_black" ]] && color0=$(normalize_hex_color "$normal_black")
    [[ -n "$normal_red" ]] && color1=$(normalize_hex_color "$normal_red")
    [[ -n "$normal_green" ]] && color2=$(normalize_hex_color "$normal_green")
    [[ -n "$normal_yellow" ]] && color3=$(normalize_hex_color "$normal_yellow")
    [[ -n "$normal_blue" ]] && color4=$(normalize_hex_color "$normal_blue")
    [[ -n "$normal_magenta" ]] && color5=$(normalize_hex_color "$normal_magenta")
    [[ -n "$normal_cyan" ]] && color6=$(normalize_hex_color "$normal_cyan")
    [[ -n "$normal_white" ]] && color7=$(normalize_hex_color "$normal_white")

    [[ -n "$bright_black" ]] && color8=$(normalize_hex_color "$bright_black")
    [[ -n "$bright_red" ]] && color9=$(normalize_hex_color "$bright_red")
    [[ -n "$bright_green" ]] && color10=$(normalize_hex_color "$bright_green")
    [[ -n "$bright_yellow" ]] && color11=$(normalize_hex_color "$bright_yellow")
    [[ -n "$bright_blue" ]] && color12=$(normalize_hex_color "$bright_blue")
    [[ -n "$bright_magenta" ]] && color13=$(normalize_hex_color "$bright_magenta")
    [[ -n "$bright_cyan" ]] && color14=$(normalize_hex_color "$bright_cyan")
    [[ -n "$bright_white" ]] && color15=$(normalize_hex_color "$bright_white")
}

finalize_palette_defaults() {
    if [[ -z "$background" || -z "$foreground" ]]; then
        echo "Error: background and foreground must be set in $input_file" >&2
        exit 1
    fi

    if [[ -z "$accent" ]]; then
        accent="${color4:-$foreground}"
    fi

    cursor="${cursor:-$foreground}"
    selection_foreground="${selection_foreground:-$background}"
    selection_background="${selection_background:-$foreground}"

    color0="${color0:-#000000}"
    color1="${color1:-#ff4444}"
    color2="${color2:-#44ff44}"
    color3="${color3:-#ffff44}"
    color4="${color4:-$accent}"
    color5="${color5:-#ff44ff}"
    color6="${color6:-#44ffff}"
    color7="${color7:-$foreground}"
    color8="${color8:-$color0}"
    color9="${color9:-$color1}"
    color10="${color10:-$color2}"
    color11="${color11:-$color3}"
    color12="${color12:-$color4}"
    color13="${color13:-$color5}"
    color14="${color14:-$color6}"
    color15="${color15:-$color7}"
}

compute_derived_colors() {
    if [[ "$appearance" == "light" ]]; then
        background_darker=$(darken_color "$background" 12)
        background_lighter=$(darken_color "$background" 4)
        background_much_lighter=$(darken_color "$background" 18)
        foreground_muted=$(darken_color "$foreground" 40)
    else
        background_darker=$(darken_color "$background" 25)
        background_lighter=$(lighten_color "$background" 10)
        background_much_lighter=$(lighten_color "$background" 20)
        foreground_muted=$(darken_color "$foreground" 40)
    fi

    accent_20=$(apply_alpha "$accent" 20)
    accent_40=$(apply_alpha "$accent" 40)

    color1_20=$(apply_alpha "$color1" 20)
    color2_20=$(apply_alpha "$color2" 20)
    color3_20=$(apply_alpha "$color3" 20)
    color3_40=$(apply_alpha "$color3" 40)
    color4_20=$(apply_alpha "$color4" 20)
    color5_20=$(apply_alpha "$color5" 20)
    color6_20=$(apply_alpha "$color6" 20)

    ensured_red=$(validate_red "$color1" "$color9")
    ensured_green=$(validate_green "$color2" "$color10")
    ensured_yellow=$(validate_yellow "$color3" "$color11")

    if [[ "$appearance" == "light" ]]; then
        ensured_red=$(darken_color "$ensured_red" 18)
        ensured_green=$(darken_color "$ensured_green" 18)
        ensured_yellow=$(darken_color "$ensured_yellow" 25)
    fi

    ensured_red_20=$(apply_alpha "$ensured_red" 20)
    ensured_green_20=$(apply_alpha "$ensured_green" 20)
    ensured_yellow_20=$(apply_alpha "$ensured_yellow" 20)
    ensured_yellow_40=$(apply_alpha "$ensured_yellow" 40)
}

render_template() {
    local template_file="$1"
    local output_file="$2"

    local content
    content=$(cat "$template_file")

    local replacements=(
        "appearance" "$appearance"
        "accent" "$accent"
        "cursor" "$cursor"
        "foreground" "$foreground"
        "background" "$background"
        "selection_foreground" "$selection_foreground"
        "selection_background" "$selection_background"
        "color0" "$color0"
        "color1" "$color1"
        "color2" "$color2"
        "color3" "$color3"
        "color4" "$color4"
        "color5" "$color5"
        "color6" "$color6"
        "color7" "$color7"
        "color8" "$color8"
        "color9" "$color9"
        "color10" "$color10"
        "color11" "$color11"
        "color12" "$color12"
        "color13" "$color13"
        "color14" "$color14"
        "color15" "$color15"
        "background_darker" "$background_darker"
        "background_lighter" "$background_lighter"
        "background_much_lighter" "$background_much_lighter"
        "foreground_muted" "$foreground_muted"
        "accent_20" "$accent_20"
        "accent_40" "$accent_40"
        "color1_20" "$color1_20"
        "color2_20" "$color2_20"
        "color3_20" "$color3_20"
        "color3_40" "$color3_40"
        "color4_20" "$color4_20"
        "color5_20" "$color5_20"
        "color6_20" "$color6_20"
        "ensured_red" "$ensured_red"
        "ensured_green" "$ensured_green"
        "ensured_yellow" "$ensured_yellow"
        "ensured_red_20" "$ensured_red_20"
        "ensured_green_20" "$ensured_green_20"
        "ensured_yellow_20" "$ensured_yellow_20"
        "ensured_yellow_40" "$ensured_yellow_40"
    )

    local index=0
    while [[ $index -lt ${#replacements[@]} ]]; do
        local key=${replacements[$index]}
        local value=${replacements[$((index + 1))]}
        value=$(escape_sed "$value")
        content=$(printf "%s" "$content" | sed "s|{{${key}}}|${value}|g")
        index=$((index + 2))
    done

    printf "%s" "$content" > "$output_file"
}

main() {
    if [[ $# -eq 1 && ("$1" == "-h" || "$1" == "--help") ]]; then
        show_usage
    fi

    if [[ $# -lt 1 || $# -gt 4 ]]; then
        show_usage
    fi

    local input_file="$1"
    local output_dir="${2:-}"
    local template_file="${3:-}"
    appearance="${4:-dark}"

    accent=""
    cursor=""
    foreground=""
    background=""
    selection_foreground=""
    selection_background=""
    color0=""
    color1=""
    color2=""
    color3=""
    color4=""
    color5=""
    color6=""
    color7=""
    color8=""
    color9=""
    color10=""
    color11=""
    color12=""
    color13=""
    color14=""
    color15=""

    local script_dir
    script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
    if [[ -z "$template_file" ]]; then
        template_file="$script_dir/omazed-theme.tpl"
    fi

    if [[ ! -f "$input_file" ]]; then
        echo "Error: File $input_file not found" >&2
        exit 1
    fi

    if [[ ! -f "$template_file" ]]; then
        echo "Error: Template file not found: $template_file" >&2
        exit 1
    fi

    if [[ -z "$output_dir" ]]; then
        output_dir="$(dirname "$input_file")"
    fi

    if [[ "$appearance" != "dark" && "$appearance" != "light" ]]; then
        echo "Error: appearance must be 'dark' or 'light'" >&2
        exit 1
    fi

    if [[ "$input_file" == *.toml ]]; then
        if grep -q "^accent\s*=\|^color0\s*=" "$input_file" 2>/dev/null; then
            parse_colors_toml "$input_file"
        else
            parse_alacritty_toml "$input_file"
        fi
    else
        parse_alacritty_toml "$input_file"
    fi

    finalize_palette_defaults
    compute_derived_colors

    mkdir -p "$output_dir"

    local output_file="$output_dir/omazed.json"

    render_template "$template_file" "$output_file"

    echo "Generated theme saved to: $output_file"
    echo "Theme name: Omazed"
    echo "Template: $template_file"
    echo "Appearance: $appearance"
    echo ""
    echo "Extracted colors:"
    echo "  background: $background"
    echo "  foreground: $foreground"
    echo "  accent: $accent"
    echo "  color0: $color0"
    echo "  color1: $color1"
    echo "  color2: $color2"
    echo "  color3: $color3"
    echo "  color4: $color4"
    echo "  color5: $color5"
    echo "  color6: $color6"
    echo "  color7: $color7"
    echo "  color8: $color8"
    echo "  color9: $color9"
    echo "  color10: $color10"
    echo "  color11: $color11"
    echo "  color12: $color12"
    echo "  color13: $color13"
    echo "  color14: $color14"
    echo "  color15: $color15"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
