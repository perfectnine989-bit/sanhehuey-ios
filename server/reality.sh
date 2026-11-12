#!/bin/bash
# Ставит VLESS Reality (sing-box) на этот сервер и печатает ссылку для приложения.
# Запуск:  bash server/reality.sh <адрес, к которому подключается приложение>
set -e
HOST="${1:-}"
PORT=8443
VER=1.12.25
ENVF=/etc/sing-box/reality.env

if [ -z "$HOST" ]; then
  echo "Укажи адрес входа: bash server/reality.sh 1.2.3.4"
  exit 1
fi

if ! command -v sing-box >/dev/null 2>&1; then
  echo "== Ставлю sing-box $VER"
  curl -fsSL -o /tmp/sing-box.deb "https://github.com/SagerNet/sing-box/releases/download/v$VER/sing-box_${VER}_linux_amd64.deb"
  dpkg -i /tmp/sing-box.deb >/dev/null
fi
mkdir -p /etc/sing-box

if [ ! -f "$ENVF" ]; then
  KEYS="$(sing-box generate reality-keypair)"
  PRIV="$(echo "$KEYS" | awk '/PrivateKey/ {print $2}')"
  PUB="$(echo "$KEYS" | awk '/PublicKey/ {print $2}')"
  UUID="$(sing-box generate uuid)"
  SID="$(sing-box generate rand --hex 8)"
  SNI=""
  for d in www.samsung.com www.asus.com www.nvidia.com www.microsoft.com; do
    if echo | timeout 6 openssl s_client -connect "$d:443" -servername "$d" -tls1_3 2>/dev/null | grep -q "TLSv1.3"; then
      SNI="$d"
      break
    fi
  done
  [ -z "$SNI" ] && SNI="www.microsoft.com"
  printf 'PRIV=%s\nPUB=%s\nUUID=%s\nSID=%s\nSNI=%s\n' "$PRIV" "$PUB" "$UUID" "$SID" "$SNI" > "$ENVF"
  chmod 600 "$ENVF"
fi
. "$ENVF"

cat > /etc/sing-box/config.json <<JSON
{
  "log": { "level": "warn" },
  "inbounds": [
    {
      "type": "vless",
      "tag": "reality-in",
      "listen": "::",
      "listen_port": $PORT,
      "users": [ { "uuid": "$UUID", "flow": "xtls-rprx-vision" } ],
      "tls": {
        "enabled": true,
        "server_name": "$SNI",
        "reality": {
          "enabled": true,
          "handshake": { "server": "$SNI", "server_port": 443 },
          "private_key": "$PRIV",
          "short_id": [ "$SID" ]
        }
      }
    }
  ],
  "outbounds": [ { "type": "direct", "tag": "direct" } ]
}
JSON

sing-box check -c /etc/sing-box/config.json
systemctl enable sing-box >/dev/null 2>&1 || true
systemctl restart sing-box
sleep 1
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  ufw allow $PORT/tcp >/dev/null
fi

if systemctl is-active --quiet sing-box; then
  echo "== Reality работает на TCP $PORT, маскировка под $SNI"
else
  echo "== ОШИБКА: sing-box не запустился"
  journalctl -u sing-box -n 15 --no-pager
  exit 1
fi
echo
echo "== Ссылка для секрета VLESS_LINK:"
echo "vless://$UUID@$HOST:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUB&sid=$SID&type=tcp#sanhehuey-reality"
