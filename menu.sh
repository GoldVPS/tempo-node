#!/bin/bash

GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RESET='\033[0m'

TEMPO_DIR="$HOME/.tempo"

confirm() {
  read -p "Are you sure? (y/n): " yn
  [[ "$yn" == "y" || "$yn" == "Y" ]]
}

show_header() {
  clear
  echo -e "\e[38;5;220m"
  echo " ██████╗  ██████╗ ██╗     ██████╗ ██╗   ██╗██████╗ ███████╗"
  echo "╚══════╝ GoldVPS Tempo Node Manager"
  echo -e "\e[0m"
  echo "https://goldvps.net"
  echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

while true; do
  show_header
  echo "1) Install / Setup Tempo Node"
  echo "2) Input Private Key & Wallet Address"
  echo "3) Start Node"
  echo "4) Check Status"
  echo "5) View Logs"
  echo "6) Test RPC"
  echo "7) Restart Node"
  echo "8) Stop Node"
  echo "9) Update Node"
  echo "10) Cleanup / Reset"
  echo "0) Exit"
  echo
  read -p "Choose: " c

  case $c in
    1) sudo bash setup.sh ;;
    2)
      read -p "Private Key (64 hex, no 0x): " PK
      read -p "Wallet Address (0x...): " ADDR
      mkdir -p "$TEMPO_DIR"
      cat > "$TEMPO_DIR/.env" <<EOF
CONSENSUS_SIGNING_KEY=$PK
CONSENSUS_FEE_RECIPIENT=$ADDR
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF
      echo "✅ Saved"
      ;;
    3) cd "$TEMPO_DIR" && ./start.sh ;;
    4) cd "$TEMPO_DIR" && ./status.sh ;;
    5) cd "$TEMPO_DIR" && ./logs.sh ;;
    6) cd "$TEMPO_DIR" && ./test-rpc.sh ;;
    7) confirm && cd "$TEMPO_DIR" && ./restart.sh ;;
    8) confirm && cd "$TEMPO_DIR" && ./stop.sh ;;
    9) confirm && cd "$TEMPO_DIR" && ./update.sh ;;
    10) confirm && cd "$TEMPO_DIR" && ./clean.sh ;;
    0) exit ;;
    *) echo "Invalid choice"; sleep 1 ;;
  esac
done
