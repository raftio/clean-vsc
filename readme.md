## Clean VSC

A distraction-free "writing room" setup for VS Code & Cursor — maximum focus, zero noise.


## What It Does

- Hides UI clutter: line numbers, scrollbars, activity bar, status bar, tabs
- Moves file path indicator to the bottom
- Centers the command palette
- Cleans up titlebar and split view separators
- Enables word wrap with deep indentation

![Centered Command Palette](assets/centered_command.png)

![Demo](assets/demo.png)

## Get Started

```bash
curl -fsSL https://raw.githubusercontent.com/raftio/clean-vsc/main/install.sh | bash
```

CLI options (when running locally):

```bash
./install.sh              # Install for VS Code + Cursor (default)
./install.sh --vscode     # Install only for VS Code
./install.sh --cursor     # Install only for Cursor
./install.sh --help       # Show all options
```

After installation:
1. Open VS Code/Cursor
2. Run command: `Enable Custom CSS and JS`
3. Restart the editor

> **Note:** Your existing `settings.json` is automatically backed up and merged (not replaced).

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/raftio/clean-vsc/main/uninstall.sh | bash
```

Or run locally:

```bash
./uninstall.sh              # Uninstall for VS Code + Cursor (default)
./uninstall.sh --vscode     # Uninstall only for VS Code
./uninstall.sh --cursor     # Uninstall only for Cursor
./uninstall.sh --help       # Show all options
```

This will:
- Remove custom CSS files (only when uninstalling both, since CSS is shared)
- Restore settings.json from backup
- Uninstall extensions from extensions.txt

## Supported Platforms

- macOS
- Linux

## Usage

- Open the Terminal
    - Press `Command+P`, type "> Focus: Terminal", then press Enter
    - Or press `Command+J`
- Show the Explorer (Files)
    - Press `Command+Shift+E`
    - Or press `Command+B`
- Find a file: Press `Command+P` and start typing the file name
- Search the workspace: Press `Command+Shift+F`
- Using Emacs keybindings: Press `Control+X` then `R` (if you installed the Emacs keybinding extension)

## More Options

- **Emacs key bindings** — Add your preferred keybinding extension to `extensions.txt`
- **Custom styles** — Edit `index.css` to tweak the appearance
- **Settings** — Modify `setting.json` before running the installer
