# Omazed

Live theme switching for Zed in Omarchy. Omazed generates a Zed theme from the current Omarchy palette and keeps it in sync when you change themes.

## Features

- Live theme syncing through Omarchy hooks
- Generates `~/.config/zed/themes/omazed.json` from `colors.toml` (fallback to `alacritty.toml`)
- Support for Omarchy v3 and Omarchy v4 (Quattro)
- One-time Zed theme selection on first run after install/update
- Lightweight Bash workflow

## Installation

**Note**: Omazed is automatically installed on Omarchy (3.8.0 onwards) when installing Zed via the **Install > Editor** menu.

### AUR (Recommended)

```bash
yay -S omazed

# Complete setup
omazed setup
```

### Manual

```bash
git clone https://github.com/aps6/omazed.git
cd omazed
./install.sh
```

## How It Works

1) Omazed ensures the Omarchy hook triggers `omazed set "$1"` on theme changes.
2) On first run after install/update, Omazed sets the Zed theme to `Omazed` once.
3) On every theme change, Omazed regenerates `~/.config/zed/themes/omazed.json` from the current Omarchy palette.

## Usage

```bash
# Set up hooks and sync once
omazed setup

# Regenerate theme for the current Omarchy palette
omazed sync

# Generate theme (used by Omarchy hook)
omazed set "theme-name"
```

## Theme Generation

Omazed's generator reads:
- `~/.local/state/omarchy/current/theme/colors.toml` (Omarchy v4)
- `~/.config/omarchy/current/theme/colors.toml` (Omarchy v3)
- Falls back to `alacritty.toml` when needed

The output is written directly to:
- `~/.config/zed/themes/omazed.json`

## Notes

- Omazed only sets the Zed theme to `Omazed` once on first run after install/update.
- After that, it never overrides your Zed theme selection.

## Troubleshooting

```bash
# Verify hook exists (Omarchy v4)
ls -la ~/.config/omarchy/hooks/theme-set.d/omazed

# Verify hook exists (Omarchy v3)
ls -la ~/.config/omarchy/hooks/theme-set

# Manual regeneration test
omazed sync
```

## Support

- Issues: https://github.com/aps6/omazed/issues
- Discussions: https://github.com/aps6/omazed/discussions
