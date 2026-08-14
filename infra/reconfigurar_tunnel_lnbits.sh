#!/bin/bash
#
# reconfigurar_tunnel_lnbits.sh
# Igual que el de BTCPay, pero para LNbits (puerto 3007).
# Corre en la Umbrel, disparado por systemd.
#
REPO_DIR="/home/umbrel/h6c13nd0l10.github.io"
LOG_FILE="/home/umbrel/tunnel_lnbits.log"

pkill -f "cloudflared tunnel --url http://localhost:3007" 2>/dev/null
sleep 2

cloudflared tunnel --url http://localhost:3007 > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!

URL=""
for i in $(seq 1 30); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
    if [ -n "$URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$URL" ]; then
    echo "[$(date)] ERROR: no se pudo obtener la URL del tunel de LNbits" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Nueva URL del tunel LNbits: $URL" >> "$LOG_FILE"

cd "$REPO_DIR" || exit 1
# Solo toca archivos que tengan "withdraw" en el nombre, para no pisar
# los botones de BTCPay que ya maneja el otro script
find . -iname "*withdraw*.html" -exec sed -i -E "s|https://[a-z0-9-]+\.trycloudflare\.com|${URL}|g" {} \;

if ! git diff --quiet; then
    git add .
    git commit -m "auto: actualizar URL del tunel LNbits a ${URL}"
    git push
    echo "[$(date)] Archivos de LNbits actualizados y subidos a GitHub" >> "$LOG_FILE"
else
    echo "[$(date)] Sin cambios" >> "$LOG_FILE"
fi

wait $TUNNEL_PID
