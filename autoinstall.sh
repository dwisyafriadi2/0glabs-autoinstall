#!/bin/bash

# Function to display the menu
show_menu() {
    # Display logo
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo "=============================="
    echo " 0G Storage Node Management Menu "
    echo "=============================="
    echo "1. Install 0G Storage Node"
    echo "2. Start Node"
    echo "3. Stop Node"
    echo "4. Check Node Status"
    echo "5. Exit"
    echo "=============================="
}

# Function to install the 0G Storage Node
install_node() {
    echo "Installing 0G Storage Node..."
    sudo apt-get update && sudo apt-get install -y clang cmake build-essential pkg-config libssl-dev curl git
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    
    cd $HOME;
    latest_tag=$(curl -s https://api.github.com/repos/0glabs/0g-storage-node/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    git clone -b "$latest_tag" https://github.com/0glabs/0g-storage-node.git || { echo "Failed to clone repository"; exit 1; }
    git clone https://github.com/0glabs/0g-storage-contracts.git || { echo "Failed to clone contracts repository"; exit 1; }
    
    cd 0g-storage-node || { echo "Directory not found"; exit 1; }
    cargo build --release || { echo "Cargo build failed"; exit 1; }
    
    mkdir -p run
    cd run || exit 1
    
    if [ ! -f "config-testnet-turbo.toml" ]; then
        wget https://docs.0g.ai/config-testnet-turbo.toml -O config-testnet-turbo.toml
    fi
    
    cp config-testnet-turbo.toml config.toml
    sed -i 's|blockchain_rpc_endpoint = ""|blockchain_rpc_endpoint = "https://evmrpc-testnet.0g.ai"|' config.toml
    sed -i 's|log_contract_address = ""|log_contract_address = "0xbD2C3F0E65eDF5582141C35969d66e34629cC768"|' config.toml
    sed -i 's|mine_contract_address = ""|mine_contract_address = "0x6815F41019255e00D6F34aAB8397a6Af5b6D806f"|' config.toml
    sed -i 's|log_sync_start_block_number = 0|log_sync_start_block_number = 940000|' config.toml
    
    read -p "Enter your miner private key (64 characters, no '0x' prefix): " miner_key
    sed -i "s|miner_key = \"\"|miner_key = \"$miner_key\"|" config.toml
    
    sudo tee /etc/systemd/system/0g-storage-node.service > /dev/null <<EOF
[Unit]
Description=0G Storage Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/target/release
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    
    sudo systemctl daemon-reload
    sudo systemctl enable 0g-storage-node
    sudo systemctl start 0g-storage-node
    echo "0G Storage Node installation and setup complete."
}

# Function to start the node
start_node() {
    echo "Starting 0G Storage Node..."
    sudo systemctl start 0g-storage-node
    echo "Node started."
}

# Function to stop the node
stop_node() {
    echo "Stopping 0G Storage Node..."
    sudo systemctl stop 0g-storage-node
    echo "Node stopped."
}

# Function to check the node status
check_status() {
    echo "Checking 0G Storage Node status..."
    sudo systemctl status 0g-storage-node
}

# Main menu loop
while true; do
    show_menu
    read -p "Please enter your choice: " choice
    case $choice in
        1) install_node ;;
        2) start_node ;;
        3) stop_node ;;
        4) check_status ;;
        5) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
