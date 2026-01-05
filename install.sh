#!/bin/bash

# Clean VSC Installer Script
# Installs custom settings and CSS for VS Code

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Clean VSC Installer${NC}"
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

# Custom CSS destination
CSS_DIR="$HOME/.clean_vsc/customs"

# Extensions file
EXT_FILE="$SCRIPT_DIR/extensions.txt"

# Function to install extensions for a specific editor CLI
install_extensions() {
    local cli_cmd=$1
    local editor_name=$2
    
    # Check if CLI command exists
    if ! command -v "$cli_cmd" &> /dev/null; then
        echo -e "   $editor_name CLI not found, skipping extensions..."
        return 1
    fi
    
    if [[ ! -f "$EXT_FILE" ]]; then
        echo -e "   extensions.txt not found, skipping..."
        return 1
    fi
    
    echo -e "${YELLOW}Installing extensions for $editor_name...${NC}"
    
    local count=0
    while IFS= read -r ext || [[ -n "$ext" ]]; do
        # Skip empty lines and comments
        [[ -z "$ext" || "$ext" == \#* ]] && continue
        
        # Trim whitespace
        ext=$(echo "$ext" | xargs)
        [[ -z "$ext" ]] && continue
        
        echo -e "   Installing $ext..."
        if "$cli_cmd" --install-extension "$ext" --force &> /dev/null; then
            echo -e "   Done: $ext"
            ((count++))
        else
            echo -e "   Failed to install $ext"
        fi
    done < "$EXT_FILE"
    
    echo -e "   Installed $count extensions for $editor_name"
    return 0
}

# Function to install for a specific editor
install_for_editor() {
    local editor_name=$1
    local user_dir=$2
    
    if [[ -d "$user_dir" ]] || [[ -d "$(dirname "$user_dir")" ]]; then
        echo -e "${YELLOW}Installing for $editor_name...${NC}"
        
        # Create User directory if not exists
        mkdir -p "$user_dir"
        
        # Backup existing settings if exists
        if [[ -f "$user_dir/settings.json" ]]; then
            backup_file="$user_dir/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
            cp "$user_dir/settings.json" "$backup_file"
            echo -e "   Backed up existing settings to: ${backup_file##*/}"
            
            # Merge settings using Python (existing settings + new settings, new settings override conflicts)
            # Handles trailing commas in JSONC
            python3 << PYEOF
import json
import re

def parse_jsonc(text):
    # Remove trailing commas before } or ]
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    return json.loads(text)

with open('$user_dir/settings.json') as f:
    existing = parse_jsonc(f.read())

# Read and replace {{HOME}} placeholder
with open('$SCRIPT_DIR/setting.json') as f:
    new_content = f.read().replace('{{HOME}}', '$HOME')
    new = parse_jsonc(new_content)

existing.update(new)
with open('$user_dir/settings.json', 'w') as f:
    json.dump(existing, f, indent=4)
PYEOF
            echo -e "   Merged settings.json (existing settings preserved)"
        else
            # No existing settings, just copy and replace placeholder
            sed "s|{{HOME}}|$HOME|g" "$SCRIPT_DIR/setting.json" > "$user_dir/settings.json"
            echo -e "   Installed settings.json"
        fi
        
        return 0
    else
        echo -e "   $editor_name not found, skipping..."
        return 1
    fi
}

# Install custom CSS
echo -e "${YELLOW}Installing custom CSS...${NC}"
mkdir -p "$CSS_DIR"
cp "$SCRIPT_DIR/index.css" "$CSS_DIR/index.css"
echo -e "   Installed index.css to $CSS_DIR"

# Install for VS Code
install_for_editor "VS Code" "$VSCODE_USER_DIR" || true

# Install for Cursor
install_for_editor "Cursor" "$CURSOR_USER_DIR" || true

# Install extensions
echo ""
install_extensions "code" "VS Code" || true
install_extensions "cursor" "Cursor" || true

echo ""
echo -e "${GREEN}Installation complete!${NC}"
echo ""
echo -e "${YELLOW}Important: To enable custom CSS, you need to:${NC}"
echo "   1. Run command: 'Enable Custom CSS and JS'"
echo "   2. Restart VS Code/Cursor"
echo ""
echo -e "${YELLOW}Note:${NC} Custom CSS path is set to: file://$CSS_DIR/index.css"


