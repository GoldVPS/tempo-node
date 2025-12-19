#!/bin/bash
#==============================================================================
# Tempo Node - GoldVPS Edition
# https://github.com/GoldVPS/tempo-node
# Powered by GoldVPS Team
#==============================================================================

set -e

echo "╔════════════════════════════════════════╗"
echo "║               TEMPO NODE               ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Run as root: sudo bash setup.sh"
    exit 1
fi

TEMPO_DIR="$HOME/.tempo"

echo "[1/7] Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh > /dev/null 2>&1
    systemctl enable docker
    systemctl start docker
    echo "✅ Docker installed"
else
    echo "✅ Docker already installed"
fi

echo "[2/7] Installing dependencies..."
apt update -qq
apt install -y curl jq ufw -qq
echo "✅ Dependencies installed"

echo "[3/7] Configuring Firewall (UFW)..."
ufw --force enable
ufw allow 22/tcp
ufw allow 8547/tcp
ufw allow 8548/tcp
ufw allow 30304/tcp
echo "✅ Firewall configured"

echo "[4/7] Creating directory..."
mkdir -p "$TEMPO_DIR"
cd "$TEMPO_DIR"
echo "✅ Directory created: $TEMPO_DIR"

echo "[5/7] Pulling Tempo Docker image..."
docker pull ghcr.io/tempoxyz/tempo:latest
echo "✅ Image pulled"

echo "[6/7] Creating config files..."

cat > .env.example <<'EOF'
CONSENSUS_SIGNING_KEY=your_64_character_private_key_here
CONSENSUS_FEE_RECIPIENT=0xYourWalletAddressHere
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF

cat > .gitignore <<'EOF'
.env
config/signing-key.txt
data/
logs/
config/
*.bak
EOF

mkdir -p data logs config

echo "[7/7] Creating helper scripts..."

# ==== START.SH ====
cat > start.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "❌ .env not found"
  exit 1
fi

source .env
CLEAN_KEY="${CONSENSUS_SIGNING_KEY#0x}"

docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null

printf "%s" "$CLEAN_KEY" > config/signing-key.txt

docker run -d \
  --name tempo-node \
  --restart unless-stopped \
  -p 8547:8545 \
  -p 8548:8546 \
  -p 30304:30303 \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/logs:/logs" \
  -v "$(pwd)/config:/config" \
  ghcr.io/tempoxyz/tempo:latest \
  node \
  --datadir /data \
  --follow \
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --ws --ws.addr 0.0.0.0 --ws.port 8546 \
  --port 30303 \
  --consensus.signing-key /config/signing-key.txt \
  --consensus.fee-recipient "$CONSENSUS_FEE_RECIPIENT"

echo "✅ Tempo node started"
EOF

# ==== STOP.SH ====
cat > stop.sh <<'EOF'
#!/bin/bash
docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null
echo "✅ Node stopped"
EOF

# ==== RESTART.SH ====
cat > restart.sh <<'EOF'
#!/bin/bash
./stop.sh
sleep 2
./start.sh
EOF

# ==== LOGS.SH ====
cat > logs.sh <<'EOF'
#!/bin/bash
docker logs -f tempo-node
EOF

# ==== STATUS.SH ====
cat > status.sh <<'EOF'
#!/bin/bash
docker ps --filter name=tempo-node
docker stats tempo-node --no-stream
EOF

# ==== TEST-RPC.SH ====
cat > test-rpc.sh <<'EOF'
#!/bin/bash
RPC="http://localhost:8547"
curl -s -X POST $RPC \
-H "Content-Type: application/json" \
-d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq .
EOF

# ==== UPDATE.SH ====
cat > update.sh <<'EOF'
#!/bin/bash
docker pull ghcr.io/tempoxyz/tempo:latest
./restart.sh
EOF

# ==== CLEAN.SH ====
cat > clean.sh <<'EOF'
#!/bin/bash
./stop.sh
rm -rf data logs config/signing-key.txt
echo "✅ All data removed"
EOF

chmod +x *.sh

echo "✅ Setup complete"
