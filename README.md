# Omarchy Zed Theme Sync

Automatically synchronize your Zed editor theme with your Omarchy Linux distribution system theme.

## Overview

This tool watches your Omarchy theme file (`~/.config/omarchy/current/theme`) and automatically updates Zed's theme to match. No complex extension setup needed - just copies themes and runs a simple watcher script.

## Features

- 🎨 **Automatic Theme Sync**: Zed theme changes instantly when you change your Omarchy system theme
- 🔄 **Real-time Monitoring**: Uses `inotifywait` for immediate file system event detection  
- 🎯 **Direct Theme Installation**: Copies themes directly to `~/.config/zed/themes/`
- ⚡ **Lightweight**: Simple bash script, no WebAssembly or extension complexity
- 🛠️ **Easy Setup**: One-command installation
- 🔧 **Systemd Integration**: Optional auto-start service

## Requirements

- Omarchy Linux distribution with theme system
- Zed editor (`zeditor` or `zed` command)
- `inotify-tools` (for file watching)
- `jq` (for JSON manipulation)

### Install Dependencies

```bash
# Arch Linux / Omarchy
sudo pacman -S inotify-tools jq

# Ubuntu/Debian  
sudo apt install inotify-tools jq

# Fedora
sudo dnf install inotify-tools jq
```

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

### Manual Install

```bash
# Copy the sync script
cp omarchy-zed-theme-sync.sh ~/.local/bin/
chmod +x ~/.local/bin/omarchy-zed-theme-sync.sh

# Install themes to Zed
~/.local/bin/omarchy-zed-theme-sync.sh install

# Test it works
~/.local/bin/omarchy-zed-theme-sync.sh test
```

## Usage

### Start Sync (Foreground)
```bash
omarchy-zed-theme-sync.sh
```

### Start as Background Daemon
```bash
omarchy-zed-theme-sync.sh --daemon
```

### Other Commands
```bash
# Install themes to Zed
omarchy-zed-theme-sync.sh install

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
3. **Theme Detection**: Reads current theme name (supports both files and symlinks)
4. **Settings Update**: Updates `~/.config/zed/settings.json` with new theme
5. **Instant Apply**: Zed automatically picks up the theme change

## Available Themes

The following Omarchy themes are included:

- **Catppuccin** - Warm, pastel theme
- **Everforest** - Green-based comfortable theme  
- **Gruvbox** - Retro groove colors
- **Kanagawa** - Japanese-inspired theme
- **Matte Black** - Sleek dark theme
- **Nord** - Arctic-inspired blue theme
- **Omarchy Dark/Light** - Official Omarchy themes
- **Osaka Jade** - Elegant green theme
- **Ristretto** - Coffee-inspired dark theme
- **Tokyo Night** - Vibrant night theme

## Configuration

### File Locations

- **Omarchy Theme**: `~/.config/omarchy/current/theme`
- **Zed Themes**: `~/.config/zed/themes/`
- **Zed Settings**: `~/.config/zed/settings.json`
- **Sync Script**: `~/.local/bin/omarchy-zed-theme-sync.sh`
- **Log File**: `~/.local/share/omarchy-zed-sync/sync.log`

### Adding Custom Themes

1. Add your `.json` theme file to the `themes/` directory
2. Run `omarchy-zed-theme-sync.sh install` to copy it to Zed
3. The sync script will automatically use it when that theme is active

### Custom Theme Mappings

Edit the `THEME_MAPPINGS` array in `omarchy-zed-theme-sync.sh`:

```bash
declare -A THEME_MAPPINGS=(
    ["my-theme.json"]="My Custom Theme"
    # Add more mappings here
)
```

## Troubleshooting

### Theme Not Syncing

```bash
# Test the setup
omarchy-zed-theme-sync.sh test

# Check if Omarchy theme file exists
ls -la ~/.config/omarchy/current/theme

# Manually sync once
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

# Test file watching
inotifywait -e modify ~/.config/omarchy/current/ &
echo "test" > ~/.config/omarchy/current/theme

# Test JSON manipulation
echo '{"theme": "old"}' | jq '.theme = "new"'
```

## Uninstallation

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

Or use the uninstall script:
```bash
./uninstall.sh
```

## Contributing

1. Fork the repository
2. Add new themes to the `themes/` directory
3. Update theme mappings if needed
4. Test thoroughly
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/aps/omarchy-theme-zed/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/aps/omarchy-theme-zed/discussions)

---

**Enjoy seamless theme synchronization! 🎨**