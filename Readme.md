<p align="center">
<img width="1536" height="1024" alt="WgOverUdp2Raw" src="https://github.com/user-attachments/assets/d332f66d-a1ca-4a02-bd6d-7eaf51aebcf5" />
</p>

# WireGuard over udp2raw

This repository provides a working setup to tunnel WireGuard traffic through `udp2raw` using the `faketcp` mode. It is designed to bypass deep packet inspection (DPI) and UDP blocking, which are common in restrictive networks.

The setup connects two servers:

- One **inside a restricted/private network** (called the `origin-server`)
- One **publicly accessible server** (called the `bridge-server`)

---

## 📁 Repository Structure

- `setup-origin-server.sh` – Installs and configures WireGuard and udp2raw on the **origin server**
- `setup-bridge-server.sh` – Installs and configures WireGuard and udp2raw on the **bridge server**
- `add-peer.sh` – Adds a new peer (client) to the `origin-server`'s WireGuard config and prints a ready-to-use config

---

## 🧠 Architecture

Unlike common setups, here the **origin-server acts as the central traffic gateway**, and the **bridge-server connects to it**.

- **Main Server:**

  - Runs `udp2raw` in **server mode** (`-s`) on port `443` with `--raw-mode faketcp`
  - Hosts both WireGuard interfaces:
    - `wg0`: Connects to bridge server (`10.0.0.2`)
    - `wg1`: Accepts local clients (`190.22.0.0/24`)
  - Uses routing tables (`123`, `124`) and `iptables` to:
    - Mark incoming traffic
    - Forward and masquerade traffic to the bridge server

- **Bridge Server:**
  - Runs `udp2raw` in **client mode** (`-c`) connecting to the origin-server at `port 443`
  - WireGuard interface has IP `10.0.0.2` and routes **all traffic via `wg0`**
  - Acts as a relay to the public internet

In short:  
**Clients connect to the origin server → Traffic is routed to bridge server → Exits to the Internet from bridge**

---

## 📦 Installation Steps

### 1. On the Origin Server (Main Gateway)

This server:

- Acts as the **udp2raw server** (`--raw-mode faketcp` on TCP port `443`)
- Hosts:
  - `wg0`: connects to bridge server (`10.0.0.2`)
  - `wg1`: serves internal clients (`190.22.0.0/24`)
- Marks and routes traffic from clients via the tunnel (`wg0`) to the outside internet

To install and configure:

    wget https://raw.githubusercontent.com/mrhn3242/WgOverUdp2Raw/main/setup-origin-server.sh
    chmod +x setup-origin-server.sh
    ./setup-origin-server.sh

This script will:

- Install WireGuard and udp2raw
- Set up `wg0` to connect to the bridge server
- Start `udp2raw` in server mode on `OriginServer:443`
- Configure `wg1` to serve LAN clients
- Enable IP forwarding and set up routing tables `123` and `124`
- Add NAT and iptables rules to forward client traffic to the tunnel

---

### 2. On the Bridge Server (Public Relay)

This server:

- Acts as a **udp2raw client**, connecting to `OriginServer:443`
- Hosts `wg0` with IP `10.0.0.2`
- Receives traffic from the origin server (via WireGuard)
- Forwards that traffic to the public Internet

To install and configure:

    ‍`wget https://raw.githubusercontent.com/mrhn3242/WgOverUdp2Raw/main/setup-bridge-server.sh
    chmod +x setup-bridge-server.sh
    ./setup-bridge-server.sh`

This script will:

- Prompts you for:
  - `origin-server` IP address (where `udp2raw` server is running)
  - The port where `udp2raw` is listening (e.g., `443`)
- Installs all required packages: `wireguard`, `udp2raw`, `iptables`, etc.
- Downloads and installs `udp2raw` client binary
- Creates a full WireGuard config (`/etc/wireguard/wg0.conf`) with:
  - `udp2raw` in **client mode**, connecting to the main-server
  - Static IP for the tunnel interface (`10.0.0.2`)
  - NAT and IP forwarding for both IPv4 and IPv6
  - Rules to route in-coming traffic from origin server to the public Internet

---

### 3. Adding a New Client

To add a new internal client (connecting to `wg1` on Origin server):

    `wget https://raw.githubusercontent.com/mrhn3242/WgOverUdp2Raw/main/add-peer.sh
    chmod +x add-peer.sh
    ./add-peer.sh`

This script will:

- Generate WireGuard keys for a new client
- Add a `[Peer]` block to the `wg1.conf`
