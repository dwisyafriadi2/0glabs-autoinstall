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
    echo "5. Check Logs"
    echo "6. Uninstall 0G Storage Node"
    echo "7. Exit"
    echo "=============================="
}

# Function to install the 0G Storage Node
install_node() {
    set -e  # Stop script on first error
    cp ~/.bashrc ~/.bashrc.bak
    echo "Installing 0G Storage Node..."
    sudo apt-get update && sudo apt-get install -y clang cmake build-essential pkg-config libssl-dev curl git jq
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    
    cd $HOME
    latest_tag=$(curl -s https://api.github.com/repos/0glabs/0g-storage-node/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    git clone -b "$latest_tag" https://github.com/0glabs/0g-storage-node.git || { echo "Failed to clone repository"; exit 1; }
    git clone https://github.com/0glabs/0g-storage-contracts.git || { echo "Failed to clone contracts repository"; exit 1; }
    
    cd 0g-storage-node || { echo "Directory not found"; exit 1; }
    mkdir -p run/log
    cargo build --release || { echo "Cargo build failed"; exit 1; }
    
    cd run || exit 1
    
    # Download the log_config file
    if [ ! -f "log_config" ]; then
        wget https://raw.githubusercontent.com/0glabs/0g-storage-node/main/log_config -O log_config
    fi

    if [ ! -f "config-testnet-turbo.toml" ]; then
        wget https://docs.0g.ai/config-testnet-turbo.toml -O config-testnet-turbo.toml
    fi
    
    cp config-testnet-turbo.toml config.toml
    sed -i 's|blockchain_rpc_endpoint = ""|blockchain_rpc_endpoint = "https://evmrpc-testnet.0g.ai"|' config.toml
    sed -i 's|log_sync_start_block_number = 0|log_sync_start_block_number = 940000|' config.toml
    
    # Read user input
    read -p "Enter your miner private key (64 characters, no '0x' prefix): " miner_key
    read -p "Enter blockchain RPC endpoint (default: https://evmrpc-testnet.0g.ai): " blockchain_rpc_endpoint
    blockchain_rpc_endpoint=${blockchain_rpc_endpoint:-https://evmrpc-testnet.0g.ai}

    # Create .env file
    cat <<EOF > $HOME/0g-storage-node/run/.env
ZGS_NODE__MINER_KEY=$miner_key
ZGS_NODE__BLOCKCHAIN_RPC_ENDPOINT=$blockchain_rpc_endpoint
EOF

    # Update config.toml
    sed -i "s|miner_key = \"\"|miner_key = \"$miner_key\"|" config.toml

    # Add aliases
    echo "alias zgs-logs='tail -f \$HOME/0g-storage-node/run/log/zgs.log.\$(date +%F)'" >> ~/.bashrc
    echo "alias zgs='$HOME/0g-storage-node/run/zgs.sh'" >> ~/.bashrc
    export PATH=$HOME/0g-storage-node/run:$PATH
    chmod +x $HOME/0g-storage-node/run/zgs.sh
    source ~/.bashrc
    hash -r
}

# Function to start the node
start_node() {
    if pgrep -x "zgs_node" > /dev/null; then
        echo "0G Storage Node is already running!"
    else
        echo "Starting 0G Storage Node..."
        bash $HOME/0g-storage-node/run/zgs.sh start
        echo "Node started."
    fi
}

# Function to stop the node
stop_node() {
    echo "Stopping 0G Storage Node..."
    bash $HOME/0g-storage-node/run/zgs.sh stop
    echo "Node stopped."
}

# Function to check logs
check_log() {
    echo "Checking 0G Storage Node log..."
    tail -f $HOME/0g-storage-node/run/log/zgs.log.$(date +%F)
}

# Function to uninstall the node
uninstall_node() {
    echo "Uninstalling 0G Storage Node..."
    cp ~/.bashrc.bak ~/.bashrc
    rm -rf $HOME/0g-storage-node $HOME/0g-storage-contracts
    source ~/.bashrc
    hash -r
    echo "0G Storage Node successfully uninstalled."
}

check_status() {
    echo "Checking Status 0G Storage Node..."
    bash $HOME/0g-storage-node/run/zgs.sh info
}

# Run menu
while true; do show_menu; read -p "Please enter your choice: " choice; case $choice in
    1) install_node ;; 2) start_node ;; 3) stop_node ;; 4) check_status ;;
    5) check_log ;; 6) uninstall_node ;; 7) echo "Exiting..."; exit 0 ;;
    *) echo "Invalid option. Please try again." ;; esac; read -p "Press Enter to continue..." </dev/tty
done
