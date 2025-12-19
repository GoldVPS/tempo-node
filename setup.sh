#!/bin/bash
#==============================================================================
# Tempo Node - GoldVPS Edition
# https://github.com/GoldVPS/tempo-node
# Powered by GoldVPS Team
#==============================================================================


set -e

echo "╔════════════════════════════════════════╗"
echo "║     TEMPO NODE - AUTOMATED SETUP        ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Run as root:   sudo bash setup.sh"
    exit 1
fi

TEMPO_DIR="$HOME/.tempo"

echo "[1/6] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    systemctl start docker
    systemctl enable docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

echo "[2/6] Installing dependencies..."
apt update -qq
apt install -y curl jq -qq
echo "✅ Dependencies installed"

echo "[3/6] Creating directory..."
mkdir -p "$TEMPO_DIR"
cd "$TEMPO_DIR"
echo "✅ Directory:   $TEMPO_DIR"

echo "[4/6] Pulling Tempo image..."
echo "This may take a few minutes..."

# Try to pull with retry
MAX_RETRIES=3
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker pull ghcr.io/tempoxyz/tempo:latest 2>&1; then
        echo "✅ Image pulled successfully"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo "⚠️  Pull failed, retrying ($RETRY_COUNT/$MAX_RETRIES)..."
            sleep 5
        else
            echo "❌ Failed to pull image after $MAX_RETRIES attempts"
            echo ""
            echo "Possible causes:"
            echo "  1. Network connectivity issue"
            echo "  2. GitHub Container Registry rate limit"
            echo "  3. DNS resolution problem"
            echo ""
            echo "Solutions:"
            echo "  - Wait a few minutes and run:  sudo bash setup.sh"
            echo "  - Check internet connection"
            echo "  - Try manual pull: docker pull ghcr.io/tempoxyz/tempo:latest"
            echo ""
            exit 1
        fi
    fi
done

echo "[5/6] Creating configuration files..."

# Create .env template
cat > "$TEMPO_DIR/.env" <<'EOF'
# Tempo Node Configuration
# Edit these values with your credentials

# Your consensus signing key (64 hex characters, NO 0x prefix)
CONSENSUS_SIGNING_KEY=EDIT_ME_YOUR_64_CHARACTER_PRIVATE_KEY_HERE

# Your fee recipient wallet address (WITH 0x prefix)
CONSENSUS_FEE_RECIPIENT=0xEDIT_ME_YOUR_WALLET_ADDRESS_HERE

# Port configuration
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304

# Logging
RUST_LOG=info
EOF

# Create .env.example
cat > "$TEMPO_DIR/.env.example" <<'EOF'
CONSENSUS_SIGNING_KEY=your_64_character_private_key_here
CONSENSUS_FEE_RECIPIENT=0xYourWalletAddressHere
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF

# Create .gitignore
cat > "$TEMPO_DIR/.gitignore" <<'EOF'
.env
config/signing-key.txt
data/
logs/
config/
*. backup
*.bak
EOF

mkdir -p "$TEMPO_DIR/data" "$TEMPO_DIR/logs" "$TEMPO_DIR/config"

echo "[6/6] Creating helper scripts..."

# start.sh
cat > "$TEMPO_DIR/start.sh" <<'STARTEOF'
#!/bin/bash
cd "$(dirname "$0")"

# Load . env
if [ ! -f .env ]; then
    echo "❌ .env not found"
    echo "Create it:   cp .env.example .env && nano .env"
    exit 1
fi

source .env

# Validate
if [ -z "$CONSENSUS_SIGNING_KEY" ] || [[ "$CONSENSUS_SIGNING_KEY" == *"EDIT_ME"* ]]; then
    echo "❌ Please edit .env first:   nano ~/. tempo/.env"
    exit 1
fi

if [ -z "$CONSENSUS_FEE_RECIPIENT" ] || [[ "$CONSENSUS_FEE_RECIPIENT" == *"EDIT_ME"* ]]; then
    echo "❌ Please edit .env first:  nano ~/.tempo/.env"
    exit 1
fi

# Remove 0x prefix if exists
CLEAN_KEY="${CONSENSUS_SIGNING_KEY#0x}"

echo "Starting Tempo Node..."
echo "Key:  ${CLEAN_KEY: 0:20}..."
echo "Recipient: $CONSENSUS_FEE_RECIPIENT"

# Stop existing
docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null

# Create directories
mkdir -p data logs config

# Create signing key file
printf "%s" "$CLEAN_KEY" > config/signing-key.txt

# Verify key file
KEY_SIZE=$(wc -c < config/signing-key.txt)
echo "Key file size: $KEY_SIZE bytes"

if [ "$KEY_SIZE" -ne 64 ]; then
    echo "❌ Invalid key size:   $KEY_SIZE (expected 64)"
    exit 1
fi

# Run container
docker run -d \
  --name tempo-node \
  --restart unless-stopped \
  -p 8547:8545 \
  -p 8548:8546 \
  -p 30304:30303 \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/logs:/logs" \
  -v "$(pwd)/config:/config" \
  -e RUST_LOG=info \
  ghcr.io/tempoxyz/tempo:latest \
  node \
  --datadir /data \
  --follow \
  --port 30303 \
  --discovery.addr 0.0.0.0 \
  --discovery.port 30303 \
  --http \
  --http.addr 0.0.0.0 \
  --http.port 8545 \
  --http.api eth,net,web3,txpool,trace \
  --ws \
  --ws.addr 0.0.0.0 \
  --ws.port 8546 \
  --ws.api eth,net,web3 \
  --consensus.signing-key /config/signing-key.txt \
  --consensus.fee-recipient "$CONSENSUS_FEE_RECIPIENT"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Node started!"
    echo "HTTP: http://localhost:8547"
    echo "WS: ws://localhost:8548"
    echo ""
    sleep 3
    echo "Latest logs:"
    docker logs tempo-node 2>&1 | tail -10
else
    echo ""
    echo "❌ Failed to start"
    docker logs tempo-node 2>&1 | tail -20
    exit 1
fi
STARTEOF

# stop.sh
cat > "$TEMPO_DIR/stop.sh" <<'EOF'
#!/bin/bash
echo "Stopping Tempo Node..."
docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null
echo "✅ Node stopped"
EOF

# restart.sh
cat > "$TEMPO_DIR/restart.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Restarting Tempo Node..."
./stop.sh
sleep 2
./start.sh
EOF

# logs.sh
cat > "$TEMPO_DIR/logs.sh" <<'EOF'
#!/bin/bash
if docker ps --format '{{.Names}}' | grep -q "^tempo-node$"; then
    echo "📋 Tempo Node Logs (Ctrl+C to exit)"
    echo "════════════════════════════════════════"
    docker logs -f tempo-node 2>&1
else
    echo "❌ Node not running.   Start with: ./start.sh"
fi
EOF

# status.sh
cat > "$TEMPO_DIR/status.sh" <<'EOF'
#!/bin/bash
echo "════════════════════════════════════════"
echo "         TEMPO NODE STATUS"
echo "════════════════════════════════════════"
if docker ps --format '{{.Names}}' | grep -q "^tempo-node$"; then
    echo ""
    echo "📦 Container:"
    docker ps --filter name=tempo-node --format "   Status: {{.Status}}"
    echo ""
    echo "💻 Resources:"
    docker stats tempo-node --no-stream --format "   CPU: {{.CPUPerc}} | Memory: {{.MemUsage}}"
    echo ""
    echo "🔌 Ports:"
    docker port tempo-node | sed 's/^/   /'
    echo ""
    echo "📋 Latest logs (last 5 lines):"
    docker logs tempo-node 2>&1 | tail -5 | sed 's/^/   /'
    echo ""
    echo "✅ Node is RUNNING"
else
    echo ""
    echo "❌ Node is NOT running"
    echo "Start with: ./start.sh"
fi
echo "════════════════════════════════════════"
EOF

# test-rpc.sh
cat > "$TEMPO_DIR/test-rpc.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source .env 2>/dev/null

RPC="http://localhost:${TEMPO_HTTP_PORT:-8547}"

echo "════════════════════════════════════════"
echo "         TEMPO RPC TESTS"
echo "════════════════════════════════════════"
echo "RPC Endpoint: $RPC"
echo ""

if !  docker ps --format '{{.Names}}' | grep -q "^tempo-node$"; then
    echo "❌ Node not running!"
    exit 1
fi

echo "1️⃣ Block Number:"
curl -s -X POST $RPC \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq . 

echo ""
echo "2️⃣ Chain ID:"
curl -s -X POST $RPC \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' | jq .

echo ""
echo "3️⃣ Sync Status:"
curl -s -X POST $RPC \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' | jq .

echo ""
echo "✅ RPC tests complete"
EOF

# update. sh
cat > "$TEMPO_DIR/update.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "Updating Tempo Node..."
docker pull ghcr.io/tempoxyz/tempo:latest
echo "Restarting node..."
./stop.sh
sleep 2
./start.sh
echo "✅ Updated to latest version"
EOF

# clean.sh
cat > "$TEMPO_DIR/clean.sh" <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
echo "════════════════════════════════════════"
echo "         CLEANUP OPTIONS"
echo "════════════════════════════════════════"
echo "1) Stop container only (keep all data)"
echo "2) Remove logs (keep blockchain data)"
echo "3) Remove EVERYTHING (including blockchain)"
echo "4) Cancel"
echo ""
read -p "Choose (1-4): " choice

case $choice in
    1)
        ./stop.sh
        echo "✅ Container stopped"
        ;;
    2)
        ./stop.sh
        rm -rf logs/*
        echo "✅ Logs removed"
        ;;
    3)
        read -p "Type 'DELETE' to confirm: " confirm
        if [ "$confirm" = "DELETE" ]; then
            ./stop.sh
            rm -rf data/ logs/ config/signing-key.txt
            echo "✅ All data removed"
        else
            echo "❌ Cancelled"
        fi
        ;;
    *)
        echo "❌ Cancelled"
        ;;
esac
EOF

# Make all executable
chmod +x "$TEMPO_DIR"/*.sh

echo "✅ All scripts created"
echo ""
echo "╔════════════════════════════════════════╗"
echo "║        ✅ SETUP COMPLETE!                 ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📝 NEXT STEPS:"
echo ""
echo "1. Edit configuration:"
echo "   nano $TEMPO_DIR/.env"
echo ""
echo "   Required:"
echo "   - CONSENSUS_SIGNING_KEY (64 chars, NO 0x)"
echo "   - CONSENSUS_FEE_RECIPIENT (WITH 0x)"
echo ""
echo "2. Start node:"
echo "   cd $TEMPO_DIR"
echo "   ./start.sh"
echo ""
echo "3. Check status:"
echo "   ./status.sh"
echo ""
echo "📚 Commands:"
echo "   ./start.sh      - Start node"
echo "   ./stop.sh       - Stop node"
echo "   ./restart.sh    - Restart node"
echo "   ./logs.sh       - View logs"
echo "   ./status.sh     - Check status"
echo "   ./test-rpc.sh   - Test RPC"
echo "   ./update.sh     - Update version"
echo "   ./clean. sh      - Cleanup data"
echo ""

exit 0
