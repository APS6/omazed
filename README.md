# Omazed

Live theme switching for Zed in Omarchy - automatically synchronize your Zed editor theme with your Omarchy system theme. Includes automatic theme generation from Alacritty configs when no Zed theme is available.

## Features

- 🎨 **Live Theme Switching**: Zed theme changes instantly when you change your Omarchy system theme
- 🤖 **Automatic Theme Generation**: Creates Zed themes from Alacritty configs when no pre-made theme exists
- ⚡ **Lightweight**: Simple bash script and systemd service
- 🛠️ **Easy Setup**: One-command installation and updates

## Installation

### AUR (Recommended)

```bash
yay -S omazed

# Complete setup
omazed setup
```

That's it! Live theme switching is now active.

### Manual Install

```bash
# Install inotiy-tools (required)
sudo pacman -S inotify-tools

git clone https://github.com/aps6/omazed.git
cd omazed
./install.sh
```

## Quick Update

### AUR Installation
```bash
yay -S omazed && omazed reload
```

### Manual Installation
```bash
cd omazed && git pull && ./install.sh
```

## How It Works

1. **Theme Installation**: Copies `.json` theme files to `~/.config/zed/themes/`
2. **File Watching**: Monitors `~/.config/omarchy/current/theme` for changes
3. **Theme Detection**: Reads current theme name
4. **Theme Resolution**: Uses pre-made theme or generates one from Alacritty config
5. **Settings Update**: Updates `~/.config/zed/settings.json` with new theme
6. **Instant Apply**: Zed automatically picks up the theme change

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
# Set up themes and service for current user
omazed setup

# Start the theme watcher (systemd service)
omazed start

# Stop systemd service
omazed stop

# Restart systemd service
omazed reload

# Check if omazed is running
omazed status

# Test current setup
omazed test

# Sync theme once and exit
omazed sync

# Remove all omazed files and stop service
omazed cleanup
```

## Troubleshooting

### Theme Not Syncing
```bash
# Test the setup
omazed test

# Restart the service
omazed reload

# Manually sync once
omazed sync
```
 > **Note**: Some extra themes may not work with the converter.

## Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/aps6/omazed/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/aps6/omazed/discussions)
