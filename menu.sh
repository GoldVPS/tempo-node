#!/bin/bash
# GoldVPS Tempo CLI (wrapper only)
# Swap & Port helper sebelum memanggil setup.sh (tidak mengubah setup.sh)

set -e

GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; CYAN='\033[0;36m'
RESET='\033[0m'

TEMPO_DIR="$HOME/.tempo"
SWAPFILE="/swapfile"
SWAP_SIZE_GB=10        # size to create when RAM < 8GB
MIN_RAM_MB=8000        # threshold in MB

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
  echo -e "🚀 Tempo Node CLI - Powered by GoldVPS Team"
  echo -e "🌐 https://goldvps.net"
  echo
  echo -e "\e[38;5;220m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\e[0m"
}

confirm() {
  while true; do
    read -p "Are you sure? (y/n): " yn
    case "$yn" in
      [Yy]) return 0 ;;
      [Nn]) return 1 ;;
      *) echo "Please answer y or n." ;;
    esac
  done
}

# Create swap only when RAM < MIN_RAM_MB and no swap active
ensure_swap_for_small_vps() {
  echo -e "${CYAN}Checking RAM and swap status...${RESET}"

  if ! mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}' 2>/dev/null); then
    echo -e "${YELLOW}Cannot read /proc/meminfo. Skipping swap check.${RESET}"
    return 1
  fi
  mem_mb=$((mem_kb/1024))
  mem_gb=$((mem_mb/1024))

  echo "Detected RAM: ${mem_mb} MB (~${mem_gb} GB)"

  # check if any swap active
  if swapon --noheadings --show=NAME | grep -q '.' 2>/dev/null; then
    echo -e "${GREEN}Swap already active. Skipping swap creation.${RESET}"
    swapon --show
    return 0
  fi

  # only create swap if RAM < MIN_RAM_MB
  if [ "$mem_mb" -ge "$MIN_RAM_MB" ]; then
    echo -e "${GREEN}RAM >= ${MIN_RAM_MB} MB. No swap will be created.${RESET}"
    return 0
  fi

  required_swap_gb=$SWAP_SIZE_GB
  echo -e "${YELLOW}RAM < ${MIN_RAM_MB} MB. Will create ${required_swap_gb}GB swap.${RESET}"

  # check available disk space on /
  avail_kb=$(df --output=avail -k / | tail -1)
  required_kb=$((required_swap_gb * 1024 * 1024))

  if [ "$avail_kb" -lt "$required_kb" ]; then
    echo -e "${RED}Not enough free disk space to create ${required_swap_gb}G swap.${RESET}"
    echo "Available (KB): $avail_kb, required (KB): $required_kb"
    echo "Skip swap creation. You can add swap manually later."
    return 1
  fi

  echo -e "${YELLOW}Creating ${required_swap_gb}G swap at ${SWAPFILE}...${RESET}"
  if command -v fallocate >/dev/null 2>&1; then
    sudo fallocate -l ${required_swap_gb}G ${SWAPFILE} || {
      echo "fallocate failed, falling back to dd..."
      sudo dd if=/dev/zero of=${SWAPFILE} bs=1M count=$((required_swap_gb*1024)) status=progress
    }
  else
    sudo dd if=/dev/zero of=${SWAPFILE} bs=1M count=$((required_swap_gb*1024)) status=progress
  fi

  sudo chmod 600 ${SWAPFILE}
  sudo mkswap ${SWAPFILE}
  sudo swapon ${SWAPFILE}

  # persist to fstab if not present
  if ! sudo grep -qF "${SWAPFILE}" /etc/fstab 2>/dev/null; then
    echo "${SWAPFILE} none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null
  fi

  echo -e "${GREEN}✅ Swap ${required_swap_gb}G created and activated.${RESET}"
  swapon --show
  return 0
}

# Ensure ufw installed & enabled, and open required ports (no duplicates)
ensure_ports() {
  echo -e "${CYAN}Ensuring firewall (ufw) and ports...${RESET}"

  # Determine ports (read from .env if exists)
  DEFAULT_HTTP=8547
  DEFAULT_WS=8548
  DEFAULT_P2P=30304

  if [ -f "$TEMPO_DIR/.env" ]; then
    # shellcheck disable=SC1090
    source "$TEMPO_DIR/.env" 2>/dev/null || true
  fi

  HTTP_PORT=${TEMPO_HTTP_PORT:-$DEFAULT_HTTP}
  WS_PORT=${TEMPO_WS_PORT:-$DEFAULT_WS}
  P2P_PORT=${TEMPO_P2P_PORT:-$DEFAULT_P2P}

  echo "Ports to allow: SSH(22), HTTP RPC(${HTTP_PORT}), WS(${WS_PORT}), P2P(${P2P_PORT})"

  # install ufw if missing
  if ! command -v ufw >/dev/null 2>&1; then
    echo -e "${YELLOW}ufw not found. Installing ufw...${RESET}"
    sudo apt-get update -qq
    sudo apt-get install -y ufw >/dev/null 2>&1 || {
      echo -e "${RED}Failed to install ufw. Skipping port open.${RESET}"
      return 1
    }
  fi

  # enable ufw if inactive
  ufw_status=$(sudo ufw status verbose 2>/dev/null || true)
  if echo "$ufw_status" | grep -qi "Status: inactive"; then
    echo -e "${YELLOW}Enabling ufw...${RESET}"
    sudo ufw --force enable >/dev/null 2>&1 || {
      echo -e "${RED}Failed to enable ufw. Continue anyway.${RESET}"
    }
  fi

  # helper to add rule if not exists
  add_rule_if_missing() {
    local rule="$1"
    # ufw status numbered or verbose; check simply if rule exists
    if sudo ufw status | grep -E -q "$rule"; then
      echo -e "${GREEN}Rule exists: $rule${RESET}"
    else
      echo -e "${YELLOW}Adding ufw rule: $rule${RESET}"
      sudo ufw allow "$rule" >/dev/null 2>&1 || echo -e "${RED}Failed to add rule: $rule${RESET}"
    fi
  }

  add_rule_if_missing "22/tcp"
  add_rule_if_missing "${HTTP_PORT}/tcp"
  add_rule_if_missing "${WS_PORT}/tcp"
  add_rule_if_missing "${P2P_PORT}/tcp"

  echo -e "${GREEN}✅ Firewall rules ensured.${RESET}"
  sudo ufw status verbose | sed 's/^/  /'
}

# Ensure tempo dir exists for options that write .env
mkdir -p "$TEMPO_DIR"

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
  read -p "Select option: " opt

  case $opt in
    1)
      echo
      echo -e "${CYAN}Step 1: swap check & create (if VPS RAM < 8GB)${RESET}"
      ensure_swap_for_small_vps || echo -e "${YELLOW}Continuing without swap.${RESET}"
      echo
      echo -e "${CYAN}Step 2: ensure ports (ufw)...${RESET}"
      ensure_ports || echo -e "${YELLOW}Continuing without ufw/port changes.${RESET}"
      echo
      echo -e "${CYAN}Launching setup.sh (this will ask for root)...${RESET}"
      sudo bash setup.sh
      read -p "Press Enter to continue..."
      ;;
    2)
      read -p "Enter CONSENSUS_SIGNING_KEY (64 hex, no 0x): " PK
      read -p "Enter CONSENSUS_FEE_RECIPIENT (0x...): " ADDR
      mkdir -p "$TEMPO_DIR"
      cat > "$TEMPO_DIR/.env" <<EOF
CONSENSUS_SIGNING_KEY=$PK
CONSENSUS_FEE_RECIPIENT=$ADDR
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF
      echo -e "${GREEN}✅ .env saved to $TEMPO_DIR/.env${RESET}"
      read -p "Press Enter to continue..."
      ;;
    3)
      cd "$TEMPO_DIR" && ./start.sh
      read -p "Press Enter to continue..."
      ;;
    4)
      cd "$TEMPO_DIR" && ./status.sh
      read -p "Press Enter to continue..."
      ;;
    5)
      cd "$TEMPO_DIR" && ./logs.sh
      read -p "Press Enter to continue..."
      ;;
    6)
      cd "$TEMPO_DIR" && ./test-rpc.sh
      read -p "Press Enter to continue..."
      ;;
    7)
      if confirm; then
        cd "$TEMPO_DIR" && ./restart.sh
      else
        echo "Cancelled."
      fi
      read -p "Press Enter to continue..."
      ;;
    8)
      if confirm; then
        cd "$TEMPO_DIR" && ./stop.sh
      else
        echo "Cancelled."
      fi
      read -p "Press Enter to continue..."
      ;;
    9)
      if confirm; then
        cd "$TEMPO_DIR" && ./update.sh
      else
        echo "Cancelled."
      fi
      read -p "Press Enter to continue..."
      ;;
    10)
      if confirm; then
        cd "$TEMPO_DIR" && ./clean.sh
      else
        echo "Cancelled."
      fi
      read -p "Press Enter to continue..."
      ;;
    0)
      echo "Bye."
      exit 0
      ;;
    *)
      echo -e "${RED}Invalid option${RESET}"
      sleep 1
      ;;
  esac
done
