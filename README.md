# Omazed

Live theme switching for Zed in Omarchy - automatically synchronize your Zed editor theme with your Omarchy system theme. Includes automatic theme generation from Alacritty configs when no Zed theme is available.

## Features

- 🎨 **Live Theme Switching**: Zed theme changes instantly when you change your Omarchy system theme
- 🤖 **Automatic Theme Generation**: Creates Zed themes from Alacritty configs when no pre-made theme exists
- 🪝 **Omarchy Hook Integration**: Uses native omarchy hooks for seamless integration (no background service needed!)
- ⚡ **Lightweight**: Simple bash script

## Installation

### AUR (Recommended)

```bash
yay -S omazed

# Complete setup
omazed setup
```

That's it! Live theme switching is now active.

**Note:** Version 1.1.0+ uses the new omarchy hook system available in omarchy 3.1.0. If you're upgrading from an older version, run `omazed setup` to automatically migrate from systemd to hooks.

### Manual Install

```bash
git clone https://github.com/aps6/omazed.git
cd omazed
./install.sh
```

**Note:** `inotify-tools` is only required if your omarchy version doesn't support hooks yet (automatic fallback).

## Quick Update

### AUR Installation
```bash
yay -S omazed && omazed setup
```

### Manual Installation
```bash
cd omazed && git pull && ./install.sh
```

## How It Works

### With Omarchy Hooks (v1.1.0+, Recommended)

1. **Theme Installation**: Copies `.json` theme files to `~/.config/zed/themes/`
2. **Hook Integration**: Adds `omazed set "$1"` to `~/.config/omarchy/hooks/theme-set`
3. **Theme Change Trigger**: When you change your Omarchy theme, omarchy calls the hook
4. **Theme Resolution**: Uses pre-made theme or generates one from Alacritty config
5. **Settings Update**: Updates `~/.config/zed/settings.json` with new theme
6. **Instant Apply**: Zed automatically picks up the theme change

### With Systemd Watcher (Fallback for older omarchy versions)

If your omarchy version doesn't support hooks yet, omazed automatically falls back to:
1. **File Watching**: Systemd service monitors `~/.config/omarchy/current/theme` for changes
2. **Background Service**: Runs `omazed watch` in the background
3. Rest of the process is the same as hook-based method

**Note:** The systemd method requires `inotify-tools` to be installed.

## Available Themes

The following default Omarchy themes are included:
- **Catppuccin** - Warm, pastel theme
- **Catppuccin Latte** - Light variant of Catppuccin
- **Everforest** - Green-based comfortable theme
- **Gruvbox** - Retro groove colors
- **Kanagawa** - Japanese-inspired theme
- **Matte Black** - Sleek dark theme
- **Nord** - Arctic-inspired blue theme
- **Osaka Jade** - Elegant green theme
- **Ristretto** - Coffee-inspired dark theme
- **Rose Pine** - Soho vibes for cosy coding (light)
- **Tokyo Night** - Vibrant night theme

## Adding Custom Themes

1. Add your `.json` theme file to the `~/.config/zed/themes` directory
   > **Tip**: You can find additional themes at [zed-themes.com](https://zed-themes.com/)
2. Ensure that the theme name matches the omarchy theme name (ex: Tokyo Night) and the file name is the theme name in lowercase separated by '-' (ex: tokyo-night).
3. The sync script will automatically use it when that theme is active

## Automatic Theme Generation

For themes without pre-made Zed themes, Omazed automatically:
- Reads the Alacritty config from `~/.config/omarchy/current/alacritty.toml`
- Extracts color palette information
- Generates a compatible Zed theme with proper syntax highlighting
- Saves the generated theme for future use

This ensures that **all** Omarchy themes work with Zed.

## Usage

### Commands
```bash
# Set up themes and hook integration (or systemd fallback)
omazed setup

# Set a specific theme by name (used by omarchy hooks)
omazed set "theme-name"

# Sync current omarchy theme to Zed
omazed sync

# Test current setup
omazed test

# Check if omazed is running (for systemd only)
omazed status

# Start/stop/reload systemd service (for systemd fallback only)
omazed start
omazed stop
omazed reload
```

### Migration from Older Versions

If you're upgrading from v1.0.x or earlier (systemd-based):

```bash
# Automatic migration
omazed setup
```

This will:
- Detect your existing systemd setup
- Stop and disable the systemd service
- Set up omarchy hook integration
- Preserve all your themes and settings

You can safely remove the old systemd service file afterwards:
```bash
rm ~/.config/systemd/user/omazed.service
```

## Troubleshooting

### Theme Not Syncing (Hook-based setup)
```bash
# Test the setup
omazed test

# Check if hook file exists and is executable
ls -la ~/.config/omarchy/hooks/theme-set

# Manually sync once to test
omazed sync

# Try setting a specific theme
omazed set "tokyo-night"
```

### Theme Not Syncing (Systemd fallback)
```bash
# Test the setup
omazed test

# Check service status
omazed status

# Restart the service
omazed reload

# Manually sync once
omazed sync
```

### Checking Which Method Is Active

```bash
# If hook exists, you're using hooks
ls ~/.config/omarchy/hooks/theme-set

# If service is running, you're using systemd fallback
systemctl --user is-active omazed.service
```

> **Note**: Some extra themes may not work with the converter.

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/aps6/omazed/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/aps6/omazed/discussions)
