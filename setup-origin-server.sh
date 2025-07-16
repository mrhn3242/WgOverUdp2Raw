#!/bin/bash

echo "=== Created by: M.Reza Hoseiny Nasab ==="
echo ""
echo ""
echo ""
echo "=== Setup Script for Origin Server ==="

# Get user inputs
read -p "🟢 Enter your origin-server server IP: " OriginServer
read -p "🚪 Enter the udp2raw port to use: " UDP2RAW_PORT
read -p "📡 Enter the WireGuard client port (used to connect to origin-server server): " WG_CLIENT_PORT

echo "⏬ Installing dependencies and udp2raw..."
apt update -y
apt install -y wireguard resolvconf curl wget

mkdir -p udp2raw
wget https://raw.githubusercontent.com/mrhn3242/WgOverUdp2Raw/main/udp2raw_binaries.tar.gz
tar -xzf udp2raw_binaries.tar.gz -C udp2raw
chmod +x ./udp2raw/udp2raw_amd64
mv ./udp2raw/udp2raw_amd64 /usr/bin/udp2raw

# Generate wg0.conf
echo "⚙️ Creating /etc/wireguard/wg0.conf..."

mkdir -p /etc/wireguard

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.1/32
PrivateKey = iFyIXpbchXZt13gp8OBdm0kigcPuw13wYz0QPCBQgGA=
ListenPort = 8912
DNS = 1.1.1.1
Table = 123
MTU = 1300

PostUp = iptables -P FORWARD ACCEPT
PostUp = iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostUp = udp2raw -s -l $OriginServer:$UDP2RAW_PORT -r 127.0.0.1:8912 --raw-mode faketcp -k "123456" -a --fix-gro > /var/log/udp2raw_server.log 2>&1 &
PreUp = sysctl -w net.ipv4.ip_forward=1
PreUp = ip rule add iif wg0 table 123 priority 456 || true
PostUp = ip route add 10.0.0.0/24 dev wg0

# IPv6 forwarding & routing
PreUp = sysctl -w net.ipv6.conf.all.forwarding=1
PreUp = ip -6 rule add iif wg0 table 123 priority 456 || true

PostDown = ip rule del iif wg0 table 123 priority 456
PostDown = ip -6 rule del iif wg0 table 123 priority 456
PostDown = pkill -f 'udp2raw -s -l $OriginServer:$UDP2RAW_PORT'
PostDown = iptables -t mangle -D FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu

[Peer]
PublicKey = uGeNs+tAoLSjKyO6W8PJrCDQctFYhuyVtddd+XTliUI=
AllowedIPs = 10.0.0.2/32,0.0.0.0/0,::/0
PersistentKeepalive = 25
EOF

# Generate wg1.conf
echo "⚙️ Creating /etc/wireguard/wg1.conf..."

cat > /etc/wireguard/wg1.conf <<EOF
[Interface]
Address = 190.22.0.1/24
PrivateKey = sJfhQdbPUld9G7vRau3Cd7swekU54Vfur9/ErZIuTVw=
ListenPort = $WG_CLIENT_PORT
Table = 124
MTU = 1300

PreUp = sysctl -w net.ipv4.ip_forward=1

# Routing table 123 setup
PostUp = ip route flush table 123 || true
PostUp = ip route add default via 10.0.0.2 dev wg0 table 123 || true
PostUp = ip route add 190.22.0.0/24 dev wg1 table 123 || true
PostUp = ip rule add fwmark 123 table 123 || true

# Mark incoming traffic
PostUp = iptables -t mangle -A PREROUTING -i wg0 -j MARK --set-mark 123

# NAT and forwarding
PostUp = iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
PostUp = iptables -A FORWARD -i wg1 -o wg0 -j ACCEPT
PostUp = iptables -A FORWARD -i wg0 -o wg1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Routing table 124
PostUp = ip route add default via 10.0.0.2 dev wg0 table 124 || true
PostUp = ip rule add from 190.22.0.0/24 lookup 124 || true

# Cleanup
PostDown = ip route flush table 123 || true
PostDown = ip rule del fwmark 123 || true
PostDown = iptables -t mangle -D PREROUTING -i wg0 -j MARK --set-mark 123
PostDown = iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg1 -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -o wg1 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
PostDown = ip route del default via 10.0.0.2 dev wg0 table 124 || true
PostDown = ip rule del from 190.22.0.0/24 lookup 124 || true
EOF

echo ""
echo "✅ Setup complete!"
echo "🔁 Please reboot your system, then run the following commands:"
echo ""
echo "  sudo wg-quick up wg0"
echo "  sudo wg-quick up wg1"