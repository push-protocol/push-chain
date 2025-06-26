#!/bin/bash
# Push Chain Validator Installer
# Usage: curl -sSL https://get.push.org/validator | bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

INSTALL_DIR="${HOME}/push-validator"
REPO_URL="https://github.com/push-protocol/push-chain"
BINARY_URL="https://github.com/push-protocol/push-chain/releases/latest/download/pchaind-linux-amd64"

echo -e "${BLUE}🚀 Push Chain Validator Installer${NC}"
echo "======================================"

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}📋 Checking prerequisites...${NC}"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker found${NC}"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        echo -e "${RED}❌ Docker Compose not found. Please install Docker Compose.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Docker Compose found${NC}"
    
    # Check if running on macOS
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo -e "${YELLOW}⚠️  Detected macOS. Using local development binary for now.${NC}"
    fi
}

# Download validator package
download_validator() {
    echo -e "${BLUE}📦 Setting up validator package...${NC}"
    
    # Create directory
    if [ -d "$INSTALL_DIR" ]; then
        echo -e "${YELLOW}⚠️  Directory $INSTALL_DIR already exists.${NC}"
        read -p "Overwrite existing installation? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            exit 1
        fi
        rm -rf "$INSTALL_DIR"
    fi
    
    mkdir -p "$INSTALL_DIR"
    
    # Clone validator files from repo
    echo -e "${BLUE}📥 Downloading validator setup files...${NC}"
    git clone --depth 1 --sparse "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || {
        # If git sparse checkout fails, try direct download
        echo -e "${YELLOW}Using fallback download method...${NC}"
        mkdir -p "$INSTALL_DIR"
        cd "$INSTALL_DIR"
        curl -sSL "$REPO_URL/archive/refs/heads/main.tar.gz" | tar xz --strip-components=2 "push-chain-main/validator"
    }
    
    cd "$INSTALL_DIR"
    
    # For sparse checkout (if git method worked)
    if [ -d .git ]; then
        git sparse-checkout init --cone
        git sparse-checkout set validator
        mv validator/* . 2>/dev/null || true
        rm -rf .git validator
    fi
}

# Interactive setup
interactive_setup() {
    echo -e "${GREEN}🔧 Quick Setup${NC}"
    echo "==============="
    
    # Check available networks from networks.json
    if [ -f "configs/networks.json" ]; then
        local enabled_networks=$(jq -r '.networks | to_entries[] | select(.value.enabled == true) | .key' configs/networks.json 2>/dev/null)
        local network_count=$(echo "$enabled_networks" | grep -c .)
        
        if [ "$network_count" -gt 1 ]; then
            # Multiple networks available
            echo ""
            echo "Available networks:"
            local i=1
            declare -a network_array
            while IFS= read -r net; do
                local net_name=$(jq -r ".networks.$net.name // '$net'" configs/networks.json)
                echo "  $i) $net_name"
                network_array[$i]="$net"
                ((i++))
            done <<< "$enabled_networks"
            
            echo ""
            read -p "Select network (1-$((i-1))): " network_choice
            NETWORK="${network_array[$network_choice]}"
        else
            # Only one network available
            NETWORK=$(echo "$enabled_networks" | head -n1)
            local net_name=$(jq -r ".networks.$NETWORK.name // '$NETWORK'" configs/networks.json)
            echo -e "${BLUE}Network: $net_name${NC}"
        fi
    else
        # Fallback to testnet if config not found
        NETWORK="testnet"
    fi
    
    # Validator name
    echo ""
    read -p "Enter your validator name: " MONIKER
    while [ -z "$MONIKER" ]; do
        echo -e "${RED}Validator name cannot be empty${NC}"
        read -p "Enter your validator name: " MONIKER
    done
    
    # Create config
    cat > .env << EOF
# Push Chain Validator Configuration

# Your validator name
MONIKER="$MONIKER"

# Network
NETWORK=$NETWORK

# That's it! Everything else is automatic 🚀
EOF
    
    echo ""
    echo -e "${GREEN}✅ Perfect! Configuration saved.${NC}"
}

# Main installation
main() {
    check_prerequisites
    download_validator
    interactive_setup
    
    # Make scripts executable
    chmod +x push-validator scripts/*.sh 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}✅ Installation complete!${NC}"
    echo ""
    echo "Next step:"
    echo -e "${BLUE}cd $INSTALL_DIR && ./push-validator start${NC}"
    echo ""
    echo "Need help? Join our Discord: https://discord.gg/pushprotocol"
}

# Run main function
main