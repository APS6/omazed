# Omarchy Zed Theme Sync

Automatically synchronize your Zed editor theme with your Omarchy system theme.

## Overview

This tool watches your Omarchy theme file (`~/.config/omarchy/current/theme`) and automatically updates Zed's theme to match.

## Features

- 🎨 **Automatic Theme Sync**: Zed theme changes instantly when you change your Omarchy system theme
- 🔄 **Real-time Monitoring**: Uses `inotifywait` for immediate file system event detection
- ⚡ **Lightweight**: Simple bash script and systemd service.
- 🛠️ **Easy Setup**: One-command installation

## Requirements

- Omarchy
- Zed editor
- `inotify-tools`
- `jq` (comes pre-installed with omarchy)

### Install Dependencies

```bash
# Arch Linux / Omarchy
sudo pacman -S inotify-tools jq

## Installation

### Quick Install

```bash
git clone https://github.com/aps/omarchy-theme-zed.git
cd omarchy-theme-zed
./install.sh
```

This will:
1. Install the sync script to `~/.local/bin/`
2. Copy all theme files to `~/.config/zed/themes/`
3. Set up systemd service for auto-start
4. Test the installation

Voila! Live theme sync should now work automatically.

## Usage

### Other Commands
```bash
# Install themes to Zed
omarchy-zed-theme-sync.sh install # This is automatically done by install.sh

# Test current setup
omarchy-zed-theme-sync.sh test

# Sync theme once and exit
omarchy-zed-theme-sync.sh sync

# Stop running daemon
omarchy-zed-theme-sync.sh stop
```

### Systemd Service
```bash
# Check service status
systemctl --user status omarchy-zed-sync.service

# Start/stop service
systemctl --user start omarchy-zed-sync.service
systemctl --user stop omarchy-zed-sync.service

# Enable/disable auto-start
systemctl --user enable omarchy-zed-sync.service
systemctl --user disable omarchy-zed-sync.service
```

## How It Works

1. **Theme Installation**: Copies `.json` theme files to `~/.config/zed/themes/`
2. **File Watching**: Monitors `~/.config/omarchy/current/theme` for changes
3. **Theme Detection**: Reads current theme name
4. **Settings Update**: Updates `~/.config/zed/settings.json` with new theme
5. **Instant Apply**: Zed automatically picks up the theme change

## Available Themes

The following default Omarchy themes are included:

- **Catppuccin** - Warm, pastel theme
- **Everforest** - Green-based comfortable theme
- **Gruvbox** - Retro groove colors
- **Kanagawa** - Japanese-inspired theme
- **Matte Black** - Sleek dark theme
- **Nord** - Arctic-inspired blue theme
- **Osaka Jade** - Elegant green theme
- **Ristretto** - Coffee-inspired dark theme
- **Tokyo Night** - Vibrant night theme

## Configuration

### Adding Custom Themes

1. Add your `.json` theme file to the `themes/` directory
2. Run `omarchy-zed-theme-sync.sh install` to copy it to Zed
3. The sync script will automatically use it when that theme is active

## Troubleshooting

### Theme Not Syncing

```bash
# Test the setup
omarchy-zed-theme-sync.sh test

# Check if Omarchy theme file exists
ls -la ~/.config/omarchy/current/theme

# Manually sync
omarchy-zed-theme-sync.sh sync
```

### Service Not Starting

```bash
# Check service logs
journalctl --user -u omarchy-zed-sync.service -f

# Check service status
systemctl --user status omarchy-zed-sync.service

# Restart service
systemctl --user restart omarchy-zed-sync.service
```

### Dependencies Issues

```bash
# Verify dependencies are installed
which inotifywait jq
```

## Uninstallation
Use the uninstall script:
```bash
./uninstall.sh
```
Or remove manually:
```bash
# Stop and disable service
systemctl --user stop omarchy-zed-sync.service
systemctl --user disable omarchy-zed-sync.service

# Remove files
rm -f ~/.local/bin/omarchy-zed-theme-sync.sh
rm -f ~/.config/systemd/user/omarchy-zed-sync.service
rm -rf ~/.local/share/omarchy-zed-sync/

# Remove themes (optional)
rm -rf ~/.config/zed/themes/
```

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/aps/omarchy-theme-zed/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/aps/omarchy-theme-zed/discussions)
