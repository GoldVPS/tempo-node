#!/bin/bash
TEMPO_DIR="$HOME/.tempo"

# === Colors ===
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# === Header (GoldVPS) ===
show_header() {
  clear
  echo -e "\e[38;5;220m"
  echo " ██████╗  ██████╗ ██╗     ██████╗ ██╗   ██╗██████╗ ███████╗"
  echo "██╔════╝ ██╔═══██╗██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝"
  echo "██║  ███╗██║   ██║██║     ██║  ██║██║   ██║██████╔╝███████╗"
  echo "██║   ██║██║   ██║██║     ██║  ██║╚██╗ ██╔╝██╔═══╝ ╚════██║"
  echo "╚██████╔╝╚██████╔╝███████╗██████╔╝ ╚████╔╝ ██║     ███████║"
  echo " ╚═════╝  ╚═════╝ ╚══════╝╚═════╝   ╚═══╝  ╚═╝     ╚══════╝"
  echo -e "\e[0m"
  echo -e "🚀 \e[1;33mTempo Node Manager\e[0m - Powered by \e[1;33mGoldVPS Team\e[0m"
  echo -e "🌐 \e[4;33mhttps://goldvps.net\e[0m"
  echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

# === Input PK & Wallet (no nano) ===
set_keys() {
  show_header
  echo -e "${CYAN}Set Consensus Key & Fee Recipient${RESET}\n"

  read -p "CONSENSUS_SIGNING_KEY (64 hex, NO 0x): " PK
  read -p "CONSENSUS_FEE_RECIPIENT (WITH 0x): " WALLET

  if [[ ${#PK} -ne 64 ]]; then
    echo -e "${RED}❌ Private key must be 64 characters${RESET}"
    sleep 2; return
  fi

  if [[ ! $WALLET =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    echo -e "${RED}❌ Invalid wallet address format${RESET}"
    sleep 2; return
  fi

  mkdir -p "$TEMPO_DIR"

  cat > "$TEMPO_DIR/.env" <<EOF
CONSENSUS_SIGNING_KEY=$PK
CONSENSUS_FEE_RECIPIENT=$WALLET
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF

  chmod 600 "$TEMPO_DIR/.env"
  echo -e "\n${GREEN}✅ Config saved to ~/.tempo/.env${RESET}"
  sleep 2
}

# === Menu Loop ===
while true; do
  show_header
  echo "1) Install / Setup Tempo Node"
  echo "2) Input Private Key & Wallet"
  echo "3) Start Node"
  echo "4) Stop Node"
  echo "5) Restart Node"
  echo "6) Check Status"
  echo "7) View Logs"
  echo "8) Test RPC"
  echo "9) Update Node"
  echo "10) Cleanup / Reset"
  echo "0) Exit"
  echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
  read -p "Select option: " opt

  case $opt in
    1) sudo bash setup.sh ;;
    2) set_keys ;;
    3) cd "$TEMPO_DIR" && ./start.sh ;;
    4) cd "$TEMPO_DIR" && ./stop.sh ;;
    5) cd "$TEMPO_DIR" && ./restart.sh ;;
    6) cd "$TEMPO_DIR" && ./status.sh ;;
    7) cd "$TEMPO_DIR" && ./logs.sh ;;
    8) cd "$TEMPO_DIR" && ./test-rpc.sh ;;
    9) cd "$TEMPO_DIR" && ./update.sh ;;
    10) cd "$TEMPO_DIR" && ./clean.sh ;;
    0) exit ;;
    *) echo -e "${RED}Invalid option${RESET}"; sleep 1 ;;
  esac
done
