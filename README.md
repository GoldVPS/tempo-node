# 🚀 Tempo Node (Testnet) — Docker Setup
Ubuntu 20.04+ — Simple CLI Installer (GoldVPS Edition)

---

## Overview

This repository provides a **simple CLI wrapper** for running an official **Tempo Node** using Docker.

**Important:** The core node engine and logic are **not modified**. This repository only adds a menu-based interface and basic server preparation.

---

## System Requirements

| Resource | Minimum | Recommended |
|---------|---------|-------------|
| CPU     | 4 vCPU  | 8 vCPU |
| RAM     | 8 GB    | 16 GB |
| Storage | 250 GB SSD | 512 GB SSD |


> VPS with less than 8 GB RAM is supported.
> The menu will **automatically create a 10 GB swap file** if needed.

---

## Get a Server (Powered by GoldVPS)

Need a reliable VPS for running Tempo Node?

**GoldVPS** provides NVMe SSD servers optimized for Docker workloads.

- ✅ Ubuntu ready
- ✅ Stable bandwidth
- ✅ NVMe SSD
- ✅ Suitable for testnet & node operations

👉 Order: https://goldvps.net  
📩 Telegram: https://t.me/miftaikyy

---

## Quick Start

```bash
git clone https://github.com/GoldVPS/tempo-node.git
cd tempo-node
chmod +x menu.sh
./menu.sh
```

Choose:

```
1) Install / Setup Tempo Node
```

During setup, the menu will:
- Create **10 GB swap** automatically if VPS RAM < 8 GB
- Enable firewall (UFW) if needed
- Open required ports
- Run the official Tempo setup script

---

## Menu Overview

```
1) Install / Setup Tempo Node
2) Input Private Key & Wallet Address
3) Start Node
4) Check Status
5) View Logs
6) Test RPC
7) Restart Node
8) Stop Node
9) Update Node
10) Cleanup / Reset
0) Exit
```

---

## Key Input (Menu Option 2)

You will be prompted to enter:

- **CONSENSUS_SIGNING_KEY**  
  64 hexadecimal characters (**without** `0x` prefix)

- **CONSENSUS_FEE_RECIPIENT**  
  Wallet address (**with** `0x` prefix)

These values are saved automatically to:

```
~/.tempo/.env
```

No manual editing is required.

---

## Ports Used

The menu automatically adds firewall rules (UFW) for the following TCP ports:

| Purpose | Port |
|-------|------|
| SSH | 22/tcp |
| HTTP RPC | 8547/tcp |
| WebSocket RPC | 8548/tcp |
| P2P | 30304/tcp |

> Existing firewall rules will **NOT** be removed or modified.

---

## Daily Operations (Cheat Sheet)

You can manage the node via the menu or manually:

```bash
cd ~/.tempo

./start.sh      # Start node
./stop.sh       # Stop node
./restart.sh    # Restart node
./status.sh     # Check status
./logs.sh       # View logs
./test-rpc.sh   # Test RPC endpoints
./update.sh     # Update node
./clean.sh      # Cleanup / reset options
```

---

## Notes & Security

- Always keep your **private keys secure**
- Never share `.env` or `config/signing-key.txt`
- Swap creation only happens when RAM < 8 GB and no swap exists
- Disk space is checked before creating swap
- Safe to use on production VPS

---

## Resources

- Tempo Documentation: https://docs.tempo.xyz
- GoldVPS Website: https://goldvps.net

---

## Disclaimer

This repository and scripts are provided **as-is**.
You are fully responsible for your server, keys, and node operation.

---

Made with ❤️ by **GoldVPS Team**

