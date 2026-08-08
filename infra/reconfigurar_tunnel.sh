#!/bin/bash
#
# reconfigurar_tunel.sh
# Corre en la Umbrel. Se ejecuta cada vez que arranca el servicio systemd
# (al boot, o si cloudflared se cae y se reinicia).
#
# Requisitos previos (una sola vez):
#   1. Clave SSH propia de la Umbrel, agregada a GitHub como "Deploy Key"
#      con permiso de escritura en el repo de los botones.
#   2. El repo clonado en /home/umbrel/donaciones-repo
#
REPO_DIR="/home/umbrel/donaciones-repo"
BOTONES_DIR="$REPO_DIR/donaciones"
LOG_FILE="/home/umbrel/tunnel.log"

# 1. Matar cualquier cloudflared viejo que haya quedado colgado
pkill cloudflared 2>/dev/null
sleep 2

# 2. Levantar el túnel nuevo
cloudflared tunnel --url http://localhost:3003 > "$LOG_FILE" 2>&1 &
TUNNEL_PID=$!

# 3. Esperar a que aparezca la URL en el log (hasta 30 segundos)
URL=""
for i in $(seq 1 30); do
    URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG_FILE" | head -1)
    if [ -n "$URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$URL" ]; then
    echo "[$(date)] ERROR: no se pudo obtener la URL del túnel" >> "$LOG_FILE"
    exit 1
fi

echo "[$(date)] Nueva URL del túnel: $URL" >> "$LOG_FILE"

# 4. Actualizar todos los botones con la URL nueva
cd "$BOTONES_DIR" || exit 1
sed -i -E "s|https://[a-z0-9-]+\.trycloudflare\.com|${URL}|g" *.html

# 5. Commitear y subir a GitHub, solo si hubo cambios reales
cd "$REPO_DIR" || exit 1
if ! git diff --quiet; then
    git add .
    git commit -m "auto: actualizar URL del túnel a ${URL}"
    git push
    echo "[$(date)] Botones actualizados y subidos a GitHub" >> "$LOG_FILE"
else
    echo "[$(date)] Sin cambios (URL igual a la anterior)" >> "$LOG_FILE"
fi

# 6. Esperar a que el proceso del túnel termine (para que systemd lo mantenga "vivo")
wait $TUNNEL_PID
