#!/bin/bash

# Created by: M.Reza Hoseiny Nasab

WG_INTERFACE="wg1"
WG_CONFIG="/etc/wireguard/$WG_INTERFACE.conf"

# --- Parse Args ---
for arg in "$@"; do
  case $arg in
    publickey=*)
      PUBKEY="${arg#*=}"
      shift
      ;;
    allowed-ips=*)
      ALLOWED_IPS="${arg#*=}"
      shift
      ;;
    persistent-keepalive=*)
      KEEPALIVE="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      exit 1
      ;;
  esac
done

# --- Prompt if any value missing ---
[[ -z "$PUBKEY" ]] && read -p "🔑 Enter the peer's Public Key: " PUBKEY
[[ -z "$ALLOWED_IPS" ]] && read -p "🌐 Enter the Allowed IPs (e.g. 190.22.0.9/32): " ALLOWED_IPS
[[ -z "$KEEPALIVE" ]] && read -p "📡 Enter PersistentKeepalive (e.g. 25, or leave blank): " KEEPALIVE

# --- Apply to active WireGuard interface ---
echo "🔧 Applying peer to active interface..."
sudo wg set $WG_INTERFACE peer "$PUBKEY" allowed-ips "$ALLOWED_IPS"

if [[ -n "$KEEPALIVE" ]]; then
  sudo wg set $WG_INTERFACE peer "$PUBKEY" persistent-keepalive "$KEEPALIVE"
fi

# --- Append to config file if not already present ---
echo "💾 Checking and updating $WG_CONFIG..."

if grep -q "$PUBKEY" "$WG_CONFIG"; then
  echo "⚠️ This peer already exists in the config file."
else
  {
    echo ""
    echo "[Peer]"
    echo "PublicKey = $PUBKEY"
    echo "AllowedIPs = $ALLOWED_IPS"
    [[ -n "$KEEPALIVE" ]] && echo "PersistentKeepalive = $KEEPALIVE"
  } | sudo tee -a "$WG_CONFIG" > /dev/null

  echo "✅ Peer added to $WG_CONFIG"
fi

echo "🎉 Done. Peer is active and config updated."