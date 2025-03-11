#!/bin/bash
#
# Zero Gravity (0G) Storage Node Installation & Management
# Script ini mencakup:
# 1. Instalasi dependencies (clang, cmake, build-essential, dll.)
# 2. Instalasi Go 1.22.0
# 3. Instalasi Rust
# 4. Clone dan build 0g-storage-node (versi v0.8.4)
# 5. Konfigurasi (miner_key, config-testnet-turbo.toml)
# 6. Setup systemd service (zgs.service)
# 7. Start/Stop Node
# 8. Download & Extract Snapshot (opsional)
# 9. Uninstall Node
#
# Sumber referensi:
# - https://j-node.net/testnet/zero-gravity-0g/0g-storage-node/installation
# - https://j-node.net/testnet/zero-gravity-0g/0g-storage-node/snapshot
# - https://github.com/0glabs/0g-storage-node
# - https://josephtran.co

# -- Konfigurasi umum
REPO_URL="https://github.com/0glabs/0g-storage-node.git"
REPO_BRANCH="v0.8.4"
CONFIG_URL="https://josephtran.co/config-testnet-turbo.toml"
SNAPSHOT_URL="https://josephtran.co/storage_0gchain_snapshot.lz4"
SNAPSHOT_FILE="storage_0gchain_snapshot.lz4"
NODE_DIR="$HOME/0g-storage-node"
RUN_DIR="$NODE_DIR/run"
CONFIG_FILE="$RUN_DIR/config-testnet-turbo.toml"
SERVICE_FILE="/etc/systemd/system/zgs.service"

# -- Banner / Logo
show_banner() {
    # Logo 0G (opsional, dapat diganti atau dihapus)
    # Anda bisa gunakan logo bawaan atau kustom:
    curl -s https://raw.githubusercontent.com/dwisyafriadi2/logo/main/logo.sh | bash
    echo "=============================="
    echo "       0G Storage Node"
    echo "=============================="
}

# -- Menu
show_menu() {
    show_banner
    echo " 1. Install Dependencies"
    echo " 2. Install & Setup 0G Storage Node (From Source)"
    echo " 3. Start Node"
    echo " 4. Stop Node"
    echo " 5. Check Node Status"
    echo " 6. Check Logs"
    echo " 7. Download & Extract Snapshot"
    echo " 8. Uninstall Node"
    echo " 9. Exit"
    echo "=============================="
}

# -- 1. Install Dependencies
install_dependencies() {
    echo ">>> Installing Dependencies..."
    sudo apt-get update
    sudo apt-get install -y clang cmake build-essential openssl pkg-config libssl-dev curl git jq wget lz4 aria2 pv
    echo ">>> Dependencies installation completed."
}

# -- Install Go 1.22.0
install_go() {
    echo ">>> Installing Go 1.22.0..."
    cd $HOME
    ver="1.22.0"
    wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
    rm "go$ver.linux-amd64.tar.gz"
    # Tambahkan PATH go ke ~/.bash_profile
    if ! grep -q '/usr/local/go/bin' "$HOME/.bash_profile"; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "$HOME/.bash_profile"
    fi
    source "$HOME/.bash_profile"
    go version
    echo ">>> Go installation completed."
}

# -- Install Rust
install_rust() {
    echo ">>> Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo ">>> Rust installation completed."
}

# -- 2. Install & Setup 0G Storage Node
install_node() {
    set -e
    # Backup .bashrc
    cp ~/.bashrc ~/.bashrc.bak || true

    echo ">>> Installing 0G Storage Node..."

    # 2.1 Install dependencies, Go, Rust
    install_dependencies
    install_go
    install_rust

    # 2.2 Remove old folder & clone fresh
    cd $HOME
    rm -rf $NODE_DIR
    git clone "$REPO_URL" "$NODE_DIR"
    cd $NODE_DIR
    git checkout "$REPO_BRANCH"
    git submodule update --init

    # 2.3 Build
    mkdir -p $RUN_DIR/log
    cargo build --release

    # 2.4 Download config-testnet-turbo.toml
    cd $RUN_DIR
    echo ">>> Downloading config file..."
    wget -O "$CONFIG_FILE" "$CONFIG_URL"

    # 2.5 Minta input private key
    printf '\033[34mEnter your private key: \033[0m' && read -s PRIVATE_KEY
    echo
    sed -i 's|^\s*#\?\s*miner_key\s*=.*|miner_key = "'"$PRIVATE_KEY"'"|' "$CONFIG_FILE" && \
    echo -e "\033[32mPrivate key has been successfully added to the config file.\033[0m"

    # 2.6 Setup systemd service
    echo ">>> Setting up systemd service..."
    sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable zgs

    # 2.7 Selesai
    echo ">>> 0G Storage Node installation completed."
    echo ">>> Use the menu to start the node."
}

# -- 3. Start Node
start_node() {
    echo ">>> Starting 0G Storage Node..."
    sudo systemctl start zgs
    sudo systemctl status zgs --no-pager
}

# -- 4. Stop Node
stop_node() {
    echo ">>> Stopping 0G Storage Node..."
    sudo systemctl stop zgs
}

# -- 5. Check Node Status
check_status() {
    echo ">>> Checking Node Status..."
    sudo systemctl status zgs --no-pager
}

# -- 6. Check Logs
check_logs() {
    LOGFILE="$RUN_DIR/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)"
    echo ">>> Checking logs: $LOGFILE"
    if [ -f "$LOGFILE" ]; then
        tail -f "$LOGFILE"
    else
        echo "Log file not found: $LOGFILE"
    fi
}

# -- 7. Download & Extract Snapshot
download_snapshot() {
    echo ">>> Stopping node before downloading snapshot..."
    sudo systemctl stop zgs

    echo ">>> Downloading snapshot from: $SNAPSHOT_URL"
    cd $HOME
    rm -f $SNAPSHOT_FILE
    aria2c -x 16 -s 16 -k 1M "$SNAPSHOT_URL"

    echo ">>> Removing old DB..."
    rm -rf "$RUN_DIR/db"

    echo ">>> Extracting snapshot..."
    lz4 -c -d "$SNAPSHOT_FILE" | pv | tar -x -C "$RUN_DIR"

    echo ">>> Restarting node..."
    sudo systemctl restart zgs
    echo ">>> Done. Check logs to see sync progress."
}

# -- 8. Uninstall Node
uninstall_node() {
    echo ">>> Uninstalling 0G Storage Node..."
    sudo systemctl stop zgs || true
    sudo systemctl disable zgs || true
    sudo rm -f "$SERVICE_FILE"
    sudo systemctl daemon-reload

    rm -rf "$NODE_DIR"
    echo ">>> 0G Storage Node successfully uninstalled."
    echo ">>> Restoring .bashrc backup if exists..."
    if [ -f ~/.bashrc.bak ]; then
        cp ~/.bashrc.bak ~/.bashrc
    fi
}

# -- 9. Exit
exit_script() {
    echo "Exiting..."
    exit 0
}

# -- Main Menu Loop
while true; do
    show_menu
    read -p "Please enter your choice [1-9]: " choice
    case $choice in
        1) install_dependencies ;;
        2) install_node ;;
        3) start_node ;;
        4) stop_node ;;
        5) check_status ;;
        6) check_logs ;;
        7) download_snapshot ;;
        8) uninstall_node ;;
        9) exit_script ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    read -p "Press Enter to continue..." </dev/tty
done
