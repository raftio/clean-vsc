#!/bin/bash

# Clean VSC Installer Script
# Installs custom settings and CSS for VS Code

set -e

REPO_BASE_URL="https://raw.githubusercontent.com/raftio/clean-vsc/main"

# Try to get script directory if running as a local file
if [[ -f "$0" ]] && [[ "$0" != "bash" ]] && [[ "$0" != "/bin/bash" ]] && [[ "$0" != "-bash" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR=""
fi

# Check if required files exist locally, otherwise download them
if [[ -n "$SCRIPT_DIR" ]] && [[ -f "$SCRIPT_DIR/index.css" ]] && [[ -f "$SCRIPT_DIR/setting.json" ]]; then
    REMOTE_MODE=false
else
    # Need to download files - use temp directory
    SCRIPT_DIR="$(mktemp -d)"
    REMOTE_MODE=true
    trap "rm -rf '$SCRIPT_DIR'" EXIT
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Clean VSC Installer${NC}"
echo "=========================="

# Download required files if running in remote mode
if [[ "$REMOTE_MODE" == true ]]; then
    echo -e "${YELLOW}Downloading configuration files...${NC}"
    curl -fsSL "$REPO_BASE_URL/index.css" -o "$SCRIPT_DIR/index.css" || { echo -e "${RED}Failed to download index.css${NC}"; exit 1; }
    curl -fsSL "$REPO_BASE_URL/setting.json" -o "$SCRIPT_DIR/setting.json" || { echo -e "${RED}Failed to download setting.json${NC}"; exit 1; }
    curl -fsSL "$REPO_BASE_URL/extensions.txt" -o "$SCRIPT_DIR/extensions.txt" 2>/dev/null || true
    echo -e "   Downloaded configuration files"
fi

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

# Install jq if not available (required for JSON merging)
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq (required for JSON merging)...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - use Homebrew
        if command -v brew &> /dev/null; then
            brew install jq
        else
            echo -e "${RED}Homebrew not found. Please install jq manually: brew install jq${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux - try apt-get, yum, or dnf
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y jq
        else
            echo -e "${RED}Package manager not found. Please install jq manually.${NC}"
            exit 1
        fi
    fi
    echo -e "   jq installed successfully"
fi

# Function to download VSIX from VS Code marketplace
download_vsix() {
    local ext_id=$1
    local output_path=$2
    
    # Parse publisher and extension name from ID (publisher.extension-name)
    local publisher="${ext_id%%.*}"
    local ext_name="${ext_id#*.}"
    
    # VS Code marketplace download URL
    local download_url="https://${publisher}.gallery.vsassets.io/_apis/public/gallery/publisher/${publisher}/extension/${ext_name}/latest/assetbyname/Microsoft.VisualStudio.Services.VSIXPackage"
    
    if curl -fsSL "$download_url" -o "$output_path" 2>/dev/null; then
        return 0
    fi
    
    # Fallback URL pattern
    download_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${ext_name}/latest/vspackage"
    if curl -fsSL "$download_url" -o "$output_path" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

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
    
    # Create temp dir for VSIX downloads
    local vsix_dir
    vsix_dir=$(mktemp -d)
    trap "rm -rf '$vsix_dir'" RETURN
    
    local count=0
    while IFS= read -r ext || [[ -n "$ext" ]]; do
        # Skip empty lines and comments
        [[ -z "$ext" || "$ext" == \#* ]] && continue
        
        # Trim whitespace
        ext=$(echo "$ext" | xargs)
        [[ -z "$ext" ]] && continue
        
        echo -e "   Installing $ext..."
        
        # For Cursor, download VSIX and install from local file
        if [[ "$cli_cmd" == "cursor" ]]; then
            local vsix_file="$vsix_dir/${ext}.vsix"
            if download_vsix "$ext" "$vsix_file"; then
                if "$cli_cmd" --install-extension "$vsix_file" --force &> /dev/null; then
                    echo -e "   Done: $ext"
                    ((count++))
                else
                    echo -e "   Failed to install $ext (install error)"
                fi
            else
                echo -e "   Failed to install $ext (download error)"
            fi
        else
            # For VS Code, use direct marketplace install
            if "$cli_cmd" --install-extension "$ext" --force &> /dev/null; then
                echo -e "   Done: $ext"
                ((count++))
            else
                echo -e "   Failed to install $ext"
            fi
        fi
    done < "$EXT_FILE"
    
    echo -e "   Installed $count extensions for $editor_name"
    return 0
}

# Function to check if editor is installed
is_editor_installed() {
    local editor_name=$1
    local cli_cmd=$2
    
    # Check if CLI command exists
    if command -v "$cli_cmd" &> /dev/null; then
        return 0
    fi
    
    # Check for application bundle on macOS
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
    
    # Check for Linux desktop entries
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [[ -f "/usr/share/applications/code.desktop" ]] && [[ "$editor_name" == "VS Code" ]]; then
            return 0
        elif [[ -f "/usr/share/applications/cursor.desktop" ]] && [[ "$editor_name" == "Cursor" ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Function to install for a specific editor
install_for_editor() {
    local editor_name=$1
    local user_dir=$2
    local cli_cmd=$3
    
    # Check if editor is actually installed
    if ! is_editor_installed "$editor_name" "$cli_cmd"; then
        echo -e "   $editor_name not installed, skipping..."
        return 1
    fi
    
    echo -e "${YELLOW}Installing for $editor_name...${NC}"
    
    # Create User directory if not exists
    mkdir -p "$user_dir"
    
    # Backup existing settings if exists
    if [[ -f "$user_dir/settings.json" ]]; then
        backup_file="$user_dir/settings.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$user_dir/settings.json" "$backup_file"
        echo -e "   Backed up existing settings to: ${backup_file##*/}"
        
        # Prepare new settings with HOME placeholder replaced
        local new_settings
        new_settings=$(sed "s|{{HOME}}|$HOME|g" "$SCRIPT_DIR/setting.json")
        
        # Strip JSONC comments from existing settings
        local existing_clean
        existing_clean=$(sed 's|//.*||g; s|/\*.*\*/||g' "$user_dir/settings.json" | \
            perl -0777 -pe 's/,(\s*[}\]])/\1/g')
        
        # Merge using jq: existing settings + new settings (new overrides existing)
        local merged
        merged=$(jq -s '.[0] * .[1]' <(echo "$existing_clean") <(echo "$new_settings") 2>/dev/null)
        
        if [[ -n "$merged" ]] && [[ "$merged" != "{}" ]] && [[ "$merged" != "null" ]]; then
            echo "$merged" > "$user_dir/settings.json"
            echo -e "   Merged settings.json (existing settings preserved)"
        else
            echo "$new_settings" > "$user_dir/settings.json"
            echo -e "   Replaced settings.json (merge failed, backup available)"
        fi
    else
        # No existing settings, just copy and replace placeholder
        sed "s|{{HOME}}|$HOME|g" "$SCRIPT_DIR/setting.json" > "$user_dir/settings.json"
        echo -e "   Installed settings.json"
    fi
    
    return 0
}

# Install custom CSS
echo -e "${YELLOW}Installing custom CSS...${NC}"
mkdir -p "$CSS_DIR"
cp "$SCRIPT_DIR/index.css" "$CSS_DIR/index.css"
echo -e "   Installed index.css to $CSS_DIR"

# Install for VS Code
install_for_editor "VS Code" "$VSCODE_USER_DIR" "code" || true

# Install for Cursor
install_for_editor "Cursor" "$CURSOR_USER_DIR" "cursor" || true

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


