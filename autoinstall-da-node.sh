#!/bin/bash

# Function to display the menu
show_menu() {
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo "=============================="
    echo " 0G DA Node Management Menu "
    echo "=============================="
    echo "1. Install Dependencies"
    echo "2. Install 0G DA Node"
    echo "3. Generate BLS Private Key"
    echo "4. Configure DA Node"
    echo "5. Start DA Node"
    echo "6. Stop DA Node"
    echo "7. Check DA Node Status"
    echo "8. Check DA Node Logs"
    echo "9. View BLS Private Key"
    echo "10. Uninstall 0G DA Node"
    echo "11. Exit"
    echo "=============================="
}

install_dependencies() {
    echo "Installing dependencies..."
    sudo apt-get update && sudo apt-get install -y curl clang cmake build-essential pkg-config libssl-dev protobuf-compiler llvm llvm-dev curl git jq
    echo "Dependencies installed."
}

install_go() {
    if command -v go &>/dev/null; then
        echo "Go is already installed. Skipping installation."
    else
        echo "Installing Go 1.22.0..."
        cd $HOME
        ver="1.22.0"
        wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
        rm "go$ver.linux-amd64.tar.gz"
        if ! grep -q '/usr/local/go/bin' "$HOME/.bashrc"; then
            echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.bashrc"
        fi
        source "$HOME/.bashrc"
        go version
        echo "Go installation completed."
    fi
}

install_rust() {
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    echo "Rust installed."
}

install_da_node() {
    echo "Installing 0G DA Node..."
    install_go
    install_rust
    cd $HOME
    git clone https://github.com/0glabs/0g-da-node.git
    cd 0g-da-node
    git fetch --all --tags
    git checkout v1.1.3
    git submodule update --init
    cargo build --release
    ./dev_support/download_params.sh
    echo "0G DA Node installed."
}

generate_bls_key() {
    if [ ! -d "$HOME/0g-da-node" ]; then
        echo "Error: 0g-da-node directory not found. Install the DA Node first."
        return
    fi
    echo "Generating BLS private key..."
    nohup cargo run --bin key-gen > $HOME/0g-da-node/bls-privatekey.log 2>&1 &
    echo "BLS private key generation started in the background. Check logs with option 9."
}

configure_da_node() {
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

sudo tee /etc/systemd/system/0gda.service > /dev/null <<EOF
[Unit]
Description=0G-DA Node
After=network.target

[Service]
User=root
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


    echo "0G DA Node configured."
}

start_da_node() {
    echo "Starting 0G DA Node..."
    sudo systemctl start 0gda
    echo "DA Node started."
}

stop_da_node() {
    echo "Stopping 0G DA Node..."
    sudo systemctl stop 0gda
    echo "DA Node stopped."
}

check_da_status() {
    echo "Checking 0G DA Node status..."
    sudo systemctl status 0gda
}

check_da_logs() {
    echo "Checking 0G DA Node logs..."
    sudo journalctl -u 0gda -f -o cat
}

view_bls_key() {
    echo "Viewing BLS Private Key log..."
    tail -f $HOME/0g-da-node/bls-privatekey.log
}

uninstall_da_node() {
    echo "Uninstalling 0G DA Node..."
    sudo systemctl stop 0gda
    sudo systemctl disable 0gda
    sudo rm /etc/systemd/system/0gda.service
    sudo systemctl daemon-reload
    sudo rm -rf $HOME/0g-da-node
    echo "0G DA Node successfully uninstalled."
}

while true; do
    show_menu
    read -p "Please enter your choice: " choice
    case $choice in
        1) install_dependencies ;;
        2) install_da_node ;;
        3) generate_bls_key ;;
        4) configure_da_node ;;
        5) start_da_node ;;
        6) stop_da_node ;;
        7) check_da_status ;;
        8) check_da_logs ;;
        9) view_bls_key ;;
        10) uninstall_da_node ;;
        11) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
