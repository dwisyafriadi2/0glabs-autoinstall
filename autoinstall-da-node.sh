#!/bin/bash

# Function to display the menu
show_menu() {
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo "=============================="
    echo " 0G DA Node & Client Management Menu "
    echo "=============================="
    echo "1. Install Dependencies"
    echo "2. Install 0G DA Node"
    echo "3. Install 0G DA Client"
    echo "4. Generate BLS Private Key"
    echo "5. Configure DA Node"
    echo "6. Start DA Node"
    echo "7. Stop DA Node"
    echo "8. Check DA Node Status"
    echo "9. Check DA Node Logs"
    echo "10. Start DA Client"
    echo "11. Stop DA Client"
    echo "12. Check DA Client Status"
    echo "13. Check DA Client Logs"
    echo "14. View BLS Private Key"
    echo "15. Uninstall 0G DA Node"
    echo "16. Uninstall 0G DA Client"
    echo "17. Exit"
    echo "=============================="
}

# Function to install dependencies (only needed once)
install_dependencies() {
    echo "Installing dependencies..."
    sudo apt-get update && sudo apt-get install -y curl clang cmake build-essential pkg-config libssl-dev protobuf-compiler llvm llvm-dev curl git jq
    echo "Dependencies installed."
}

# Function to install Rust
install_rust() {
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    echo "Rust installed."
}

# Function to download and build the 0G DA Node binary
install_da_node() {
    echo "Installing 0G DA Node..."
    install_rust  # Ensure Rust is installed before building
    cd $HOME
    git clone https://github.com/0glabs/0g-da-node.git
    cd 0g-da-node
    git fetch --all --tags
    git checkout v1.1.3
    git submodule update --init
    cargo build --release
    ./dev_support/download_params.sh
    create_service
    echo "0G DA Node installed."
}

# Function to install the 0G DA Client
install_da_client() {
    echo "Installing 0G DA Client..."
    sudo apt-get update && sudo apt-get install -y cmake
    git clone -b v1.0.0-testnet https://github.com/0glabs/0g-da-client.git
    cd 0g-da-client
    git stash
    git fetch --all --tags
    git checkout f8db250
    git submodule update --init
    echo "0G DA Client installation complete."
}

# Function to generate BLS private key
generate_bls_key() {
    echo "Generating BLS private key..."
    cd $HOME/0g-da-node
    nohup cargo run --bin key-gen > $HOME/0g-da-node/bls-privatekey.log 2>&1 &
    echo "BLS private key generation started in the background. Check logs with option 9."
}

# Function to configure the node
configure_node() {
    echo "Configuring 0G DA Node..."
    vps_ip=$(curl -4 icanhazip.com)
    read -p "Enter your BLS private key: " bls_key
    read -p "Enter your signer Ethereum private key: " signer_eth_key
    read -p "Enter your miner Ethereum private key: " miner_eth_key

    cat <<EOF > $HOME/0g-da-node/config.toml
log_level = "info"
data_path = "./db/"
encoder_params_dir = "params/"
grpc_listen_address = "0.0.0.0:34000"
eth_rpc_endpoint = "https://evmrpc-testnet.0g.ai"
socket_address = "$vps_ip:34000"
da_entrance_address = "0x857C0A28A8634614BB2C96039Cf4a20AFF709Aa9"
start_block_number = 940000
signer_bls_private_key = "$bls_key"
signer_eth_private_key = "$signer_eth_key"
miner_eth_private_key = "$miner_eth_key"
enable_das = "true"
EOF

    echo "0G DA Node configured."
}

# Function to create systemd service
create_service() {
    echo "Creating systemd service for 0G DA Node..."
    sudo tee /etc/systemd/system/0gda.service > /dev/null <<EOF
[Unit]
Description=0G-DA Node
After=network.target

[Service]
User=$USER
Environment="RUST_BACKTRACE=full"
Environment="RUST_LOG=debug"
WorkingDirectory=$HOME/0g-da-node
ExecStart=$HOME/0g-da-node/target/release/server --config $HOME/0g-da-node/config.toml
Restart=always
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable 0gda
    echo "Systemd service created."
}

# Function to start the node
start_node() {
    echo "Starting 0G DA Node..."
    sudo systemctl start 0gda
    echo "Node started."
}

# Function to stop the node
stop_node() {
    echo "Stopping 0G DA Node..."
    sudo systemctl stop 0gda
    echo "Node stopped."
}

# Function to check the node status
check_status() {
    echo "Checking 0G DA Node status..."
    sudo systemctl status 0gda
}

# Function to check node logs
check_logs() {
    echo "Checking 0G DA Node logs..."
    sudo journalctl -u 0gda -f -o cat
}

# Function to view BLS Private Key log
view_bls_key() {
    echo "Viewing BLS Private Key log..."
    tail -f $HOME/0g-da-node/bls-privatekey.log
}

# Function to uninstall the node
uninstall_node() {
    echo "Uninstalling 0G DA Node..."
    sudo systemctl stop 0gda
    sudo systemctl disable 0gda
    sudo rm /etc/systemd/system/0gda.service
    sudo systemctl daemon-reload
    rm -rf $HOME/0g-da-node
    echo "0G DA Node successfully uninstalled."
}

# Main menu loop
while true; do
    show_menu
    read -p "Please enter your choice: " choice
    case $choice in
        1) install_dependencies ;;
        2) install_da_node ;;
        3) install_da_client ;;
        4) generate_bls_key ;;
        5) configure_node ;;
        6) start_node ;;
        7) stop_node ;;
        8) check_status ;;
        9) check_logs ;;
        10) start_da_client ;;
        11) stop_da_client ;;
        12) check_da_client_status ;;
        13) check_da_client_logs ;;
        14) view_bls_key ;;
        15) uninstall_node ;;
        16) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
