#!/bin/bash

# Clean VSC Uninstaller Script
# Removes custom settings and CSS installed by install.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${RED}Clean VSC Uninstaller${NC}"
echo "=========================="

# Detect OS and set VS Code paths
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
    CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    VSCODE_USER_DIR="$HOME/.config/Code/User"
    CURSOR_USER_DIR="$HOME/.config/Cursor/User"
else
    echo -e "${RED}Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

# Custom CSS directory
CSS_DIR="$HOME/.clean_vsc"

REPO_BASE_URL="https://raw.githubusercontent.com/raftio/clean-vsc/main"

# Try to get script directory if running as a local file
if [[ -f "$0" ]] && [[ "$0" != "bash" ]] && [[ "$0" != "/bin/bash" ]] && [[ "$0" != "-bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR=""
fi

# Check if extensions.txt exists locally, otherwise download it
if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/extensions.txt" ]]; then
    EXT_FILE="$SCRIPT_DIR/extensions.txt"
else
    # Download to temp
    EXT_FILE="$(mktemp)"
    trap "rm -f '$EXT_FILE'" EXIT
    curl -fsSL "$REPO_BASE_URL/extensions.txt" -o "$EXT_FILE" 2>/dev/null || EXT_FILE=""
fi

# Function to uninstall extensions from extensions.txt only
uninstall_extensions() {
    local cli_cmd=$1
    local editor_name=$2
    
    if ! command -v "$cli_cmd" &> /dev/null; then
        echo -e "   $editor_name CLI not found, skipping extensions..."
        return 1
    fi
    
    if [[ -z "$EXT_FILE" ]] || [[ ! -f "$EXT_FILE" ]]; then
        echo -e "   extensions.txt not found, skipping..."
        return 1
    fi
    
    echo -e "${YELLOW}Uninstalling extensions for $editor_name...${NC}"
    
    local count=0
    while IFS= read -r ext || [[ -n "$ext" ]]; do
        # Skip empty lines and comments
        [[ -z "$ext" || "$ext" == \#* ]] && continue
        
        # Trim whitespace
        ext=$(echo "$ext" | xargs)
        [[ -z "$ext" ]] && continue
        
        echo -e "   Removing $ext..."
        if "$cli_cmd" --uninstall-extension "$ext" &> /dev/null; then
            echo -e "   Removed: $ext"
            ((count++))
        else
            echo -e "   Not installed or failed: $ext"
        fi
    done < "$EXT_FILE"
    
    echo -e "   Removed $count extensions from $editor_name"
    return 0
}

# Function to check if editor is installed
is_editor_installed() {
    local editor_name=$1
    local cli_cmd=$2
    
    if command -v "$cli_cmd" &> /dev/null; then
        return 0
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local app_path
        case "$editor_name" in
            "VS Code")
                app_path="/Applications/Visual Studio Code.app"
                ;;
            "Cursor")
                app_path="/Applications/Cursor.app"
                ;;
        esac
        
        if [[ -n "$app_path" ]] && [[ -d "$app_path" ]]; then
            return 0
        fi
    fi
    
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f "/usr/share/applications/code.desktop" ]] && [[ "$editor_name" == "VS Code" ]]; then
            return 0
        elif [[ -f "/usr/share/applications/cursor.desktop" ]] && [[ "$editor_name" == "Cursor" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to restore settings from backup
restore_settings() {
    local editor_name=$1
    local user_dir=$2
    
    if [[ ! -d "$user_dir" ]]; then
        echo -e "   $editor_name: No User directory found"
        return 1
    fi
    
    echo -e "${YELLOW}Restoring $editor_name settings...${NC}"
    
    # Find the most recent backup
    local latest_backup
    latest_backup=$(ls -t "$user_dir"/settings.json.backup.* 2>/dev/null | head -1)
    
    if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup" ]]; then
        cp "$latest_backup" "$user_dir/settings.json"
        echo -e "   Restored from: ${latest_backup##*/}"
        # Remove backup files after restore
        rm -f "$user_dir"/settings.json.backup.*
        echo -e "   Cleaned up backup files"
    else
        echo -e "   No backup found, settings.json unchanged"
    fi
    
    return 0
}

# Remove custom CSS directory
echo -e "${YELLOW}Removing custom CSS...${NC}"
if [[ -d "$CSS_DIR" ]]; then
    rm -rf "$CSS_DIR"
    echo -e "   Removed $CSS_DIR"
else
    echo -e "   CSS directory not found, skipping..."
fi

# Process VS Code
if is_editor_installed "VS Code" "code"; then
    echo ""
    restore_settings "VS Code" "$VSCODE_USER_DIR"
fi

# Process Cursor
if is_editor_installed "Cursor" "cursor"; then
    echo ""
    restore_settings "Cursor" "$CURSOR_USER_DIR"
fi

# Uninstall extensions from extensions.txt only
echo ""
uninstall_extensions "code" "VS Code" || true
uninstall_extensions "cursor" "Cursor" || true

echo ""
echo -e "${GREEN}Uninstallation complete!${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} You may need to:"
echo "   1. Run command: 'Disable Custom CSS and JS'"
echo "   2. Restart VS Code/Cursor"

