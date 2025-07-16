#!/bin/bash

echo "=== Created by: M.Reza Hoseiny Nasab ==="
echo ""
echo ""
echo ""
echo "=== WireGuard + udp2raw Setup (Bridge  Server) ==="

read -p "🌐 Enter the origin-server server IP: " OriginServer
read -p "🚪 Enter the udp2raw port on origin-server: " OriginServerUdp2raw_PORT

echo "⏬ Installing required packages..."

# Handle apt lock
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 ; do
  echo "🔒 Waiting for apt lock to be released..."
  sleep 2
done

apt install -y wireguard resolvconf

mkdir -p udp2raw
wget https://raw.githubusercontent.com/mrhn3242/WgOverUdp2Raw/main/udp2raw_binaries.tar.gz
tar -xzf udp2raw_binaries.tar.gz -C udp2raw
chmod +x ./udp2raw/udp2raw_amd64
mv ./udp2raw/udp2raw_amd64 /usr/bin/udp2raw

echo "⚙️ Creating /etc/wireguard/wg0.conf..."

mkdir -p /etc/wireguard

cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.0.0.2/32,fd10:0:0:2::1/64
PrivateKey = GPcDC9dJlhC3MeRFqow/T6NuUpfcMkMLd3RmQvV/IVM=

# Enable IPv4 forwarding
PreUp = sysctl -w net.ipv4.ip_forward=1

# UDP2RAW client
PostUp = udp2raw -c -r $OriginServer:$OriginServerUdp2raw_PORT -l 127.0.0.1:4096 --raw-mode faketcp -k "123456" -a --fix-gro > /var/log/udp2raw_client.log 2>&1 &

# IPv4 routing and NAT
PreUp = iptables -t mangle -A PREROUTING -i wg0 -j MARK --set-mark 0x30
PreUp = iptables -t nat -A POSTROUTING ! -o wg0 -m mark --mark 0x30 -j MASQUERADE
PostUp = iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
PostUp = iptables -P FORWARD ACCEPT
PostUp = iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

PostDown = iptables -t mangle -D PREROUTING -i wg0 -j MARK --set-mark 0x30
PostDown = iptables -t nat -D POSTROUTING ! -o wg0 -m mark --mark 0x30 -j MASQUERADE
PostDown = iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# IPv6 forwarding
PreUp = sysctl -w net.ipv6.conf.all.forwarding=1
PreUp = ip6tables -t mangle -A PREROUTING -i wg0 -j MARK --set-mark 0x30
PreUp = ip6tables -t nat -A POSTROUTING ! -o wg0 -m mark --mark 0x30 -j MASQUERADE
PostDown = ip6tables -t mangle -D PREROUTING -i wg0 -j MARK --set-mark 0x30
PostDown = ip6tables -t nat -D POSTROUTING ! -o wg0 -m mark --mark 0x30 -j MASQUERADE

# Kill udp2raw on shutdown
PostDown = pkill -f 'udp2raw -c -r $OriginServer:$OriginServerUdp2raw_PORT'

[Peer]
PublicKey = XkIjdcHwQUd1vI1uCye6qOsi2rOMpYR4Q/oiNrqMnDY=
AllowedIPs = 10.0.0.1/24, fd10::/64
Endpoint = 127.0.0.1:4096
PersistentKeepalive = 25
EOF

echo ""
echo "✅ WireGuard config created at /etc/wireguard/wg0.conf"
echo "🔁 Please reboot your server and run:"
echo ""
echo "  sudo wg-quick up wg0"