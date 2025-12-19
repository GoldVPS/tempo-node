#!/bin/bash
set -e

# Root check
if [ "$EUID" -ne 0 ]; then
  echo "Run as root: sudo bash setup.sh"
  exit 1
fi

TEMPO_DIR="$HOME/.tempo"

echo "🟡 GoldVPS | Tempo Node Setup"

# Docker
if ! command -v docker &>/dev/null; then
  curl -fsSL https://get.docker.com | sh
  systemctl enable docker
  systemctl start docker
fi

# Dependencies
apt update -qq
apt install -y curl jq ufw -qq

# Firewall
echo "Configuring UFW..."
ufw allow 22/tcp
ufw allow 8547/tcp
ufw allow 8548/tcp
ufw allow 30304/tcp
ufw --force enable

# Directory
mkdir -p "$TEMPO_DIR"/{data,logs,config}
cd "$TEMPO_DIR"

# Pull image
docker pull ghcr.io/tempoxyz/tempo:latest

# .env.example
cat > .env.example <<EOF
CONSENSUS_SIGNING_KEY=your_64_character_private_key_here
CONSENSUS_FEE_RECIPIENT=0xYourWalletAddressHere
TEMPO_HTTP_PORT=8547
TEMPO_WS_PORT=8548
TEMPO_P2P_PORT=30304
RUST_LOG=info
EOF

# start.sh
cat > start.sh <<'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source .env || { echo ".env not found"; exit 1; }

CLEAN_KEY="${CONSENSUS_SIGNING_KEY#0x}"
echo "$CLEAN_KEY" > config/signing-key.txt

docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null

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
  --http --http.addr 0.0.0.0 --http.port 8545 \
  --ws --ws.addr 0.0.0.0 --ws.port 8546 \
  --port 30303 \
  --consensus.signing-key /config/signing-key.txt \
  --consensus.fee-recipient "$CONSENSUS_FEE_RECIPIENT"

echo "✅ Node started"
EOF

# stop.sh
cat > stop.sh <<'EOF'
#!/bin/bash
docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null
echo "✅ Node stopped"
EOF

# restart.sh
cat > restart.sh <<'EOF'
#!/bin/bash
./stop.sh
sleep 2
./start.sh
EOF

# logs.sh
cat > logs.sh <<'EOF'
#!/bin/bash
docker logs -f tempo-node
EOF

# status.sh
cat > status.sh <<'EOF'
#!/bin/bash
docker ps --filter name=tempo-node
docker stats tempo-node --no-stream
EOF

# test-rpc.sh
cat > test-rpc.sh <<'EOF'
#!/bin/bash
curl -s -X POST http://localhost:8547 \
-H "Content-Type: application/json" \
-d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | jq .
EOF

# update.sh
cat > update.sh <<'EOF'
#!/bin/bash
docker pull ghcr.io/tempoxyz/tempo:latest
./restart.sh
EOF

# clean.sh
cat > clean.sh <<'EOF'
#!/bin/bash
docker stop tempo-node 2>/dev/null
docker rm tempo-node 2>/dev/null
rm -rf data logs config/signing-key.txt
echo "❌ All data removed"
EOF

chmod +x *.sh

echo "✅ Setup complete. Run ./menu.sh"
