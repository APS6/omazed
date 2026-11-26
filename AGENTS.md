# AGENTS.md

Bash utility (`set -euo pipefail`, no build step or test suite) that syncs Omarchy themes and fonts into Zed.

## Files

- `omazed` — CLI (`setup`, `sync`, `set`, `set-font`) and Omarchy v3/v4 hook setup. Resolves helper scripts from `$SCRIPT_DIR` before `~/.local/bin` and `/usr/bin`, so local runs test local edits.
- `omazed-generator.sh` — Parses `colors.toml` (v3/v4) or `alacritty.toml` and renders `omazed-theme.tpl` to `~/.config/zed/themes/omazed.json`.
- `omazed-theme.tpl` — Zed `v0.2.0` theme template.
- `omazed-font.sh` — Syncs Omarchy's monospace font into `~/.config/zed/settings.json`.
- `install.sh` / `uninstall.sh` — Local install (`~/.local/bin`, hooks).

## Rules

- Keep `{{token}}` placeholders in `omazed-theme.tpl` matched 1:1 with `replacements` in `render_template` (`omazed-generator.sh`).
- Preserve user Zed settings: `settings.json` can have JSONC `//` comments and trailing commas (`omazed-font.sh` strips them safely), and `set_initial_theme_once` uses `~/.local/share/omazed/initialized` so manual theme changes aren't overwritten.
- Stick to `bash`, `jq`, `perl`, `sed`, `gawk`, and GNU `grep` (`-P`). Update `install.sh`, `uninstall.sh`, and note `omacom/omarchy-pkgs` if adding files or dependencies.

## Verification

Run checks against a temp directory (`HOME` and `XDG_STATE_HOME` isolated, since Omarchy exports `XDG_STATE_HOME`) so real user config isn't touched:

```bash
bash -n omazed omazed-generator.sh omazed-font.sh install.sh uninstall.sh

h=$(mktemp -d)
mkdir -p "$h/.local/state/omarchy/current/theme" "$h/.config/zed"
printf 'tokyo-night\n' > "$h/.local/state/omarchy/current/theme.name"
printf 'background = "#1a1b26"\nforeground = "#c0caf5"\naccent = "#7aa2f7"\n' > "$h/.local/state/omarchy/current/theme/colors.toml"
printf 'JetBrainsMono Nerd Font\n' > "$h/.local/state/omarchy/current/font.txt"
XDG_STATE_HOME="$h/.local/state" HOME="$h" bash ./omazed sync
jq empty "$h/.config/zed/themes/omazed.json" && ! grep -q '{{' "$h/.config/zed/themes/omazed.json"

printf '// Zed settings\n{\n  "theme": "Omazed",\n  "url": "https://example.com",\n}\n' > "$h/.config/zed/settings.json"
HOME="$h" bash ./omazed-font.sh "JetBrainsMono Nerd Font"
jq empty "$h/.config/zed/settings.json"
rm -rf "$h"
```

When touching `omazed-generator.sh` or `omazed-theme.tpl`, also verify `opaque` and `blurred` across `/usr/share/omarchy/themes/*/` (skip `osaka-jade`, which has no palette file).

## Release flow

- Releases use `v*` Git tags matching `v(?P<version>[0-9]+(?:\.[0-9]+)*)`.
- The Omarchy package repository (`omacom/omarchy-pkgs`, `pkgbuilds/omazed/`) watches tags on `https://github.com/aps6/omazed.git` on a six-hourly schedule and publishes updates through the fast release ring.
- Upstream automation only bumps `pkgver`, resets `pkgrel`, and refreshes `sha256sums`. If a release adds new installed files or package dependencies, open a PR in `omacom/omarchy-pkgs` to update `pkgbuilds/omazed/PKGBUILD`.
