#!/bin/bash

# Script para enviar eventos al endpoint de Ansible EDA Event Stream
# Uso: ./send-event.sh [payload_file.json]

URL="https://aap-aap.apps-crc.testing/eda-event-streams/api/eda/v1/external_event_stream/703efa48-f7b6-4229-95fe-53db03f5b60a/post/"

# Payload por defecto (simula una alerta de Prometheus/Alertmanager)
DEFAULT_PAYLOAD='{
  "status": "firing",
  "labels": {
    "alertname": "HighErrorRate",
    "severity": "warning",
    "namespace": "demo-eda"
  },
  "annotations": {
    "summary": "High error rate detected",
    "description": "Error rate is above 5%"
  },
  "startsAt": "2024-01-01T00:00:00Z",
  "endsAt": null
}'

# Si se proporciona un archivo, usarlo; si no, usar el payload por defecto
if [ -n "$1" ]; then
    PAYLOAD=$(cat "$1")
else
    PAYLOAD="$DEFAULT_PAYLOAD"
fi

echo "Enviando evento a: $URL"
echo "Payload:"
echo "$PAYLOAD" | jq .

# Enviar el evento
RESPONSE=$(curl -X POST "$URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: token" \
  -d "$PAYLOAD" \
  -w "\nHTTP_CODE:%{http_code}" \
  -k -s)

# Separar respuesta y código HTTP
HTTP_CODE=$(echo "$RESPONSE" | grep -o "HTTP_CODE:[0-9]*" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed 's/HTTP_CODE:[0-9]*$//')

echo ""
echo "Respuesta HTTP: $HTTP_CODE"
echo "Cuerpo de la respuesta:"
echo "$BODY" | jq . 2>/dev/null || echo "$BODY"

