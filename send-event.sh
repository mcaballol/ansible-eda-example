#!/bin/bash

# Script para enviar eventos al endpoint de Ansible EDA Event Stream
# Uso: ./send-event.sh [payload_file.json]

URL="https://aap-aap.apps-crc.testing/eda-event-streams/api/eda/v1/external_event_stream/703efa48-f7b6-4229-95fe-53db03f5b60a/post/"

# Payload por defecto (simula una alerta de Prometheus/Alertmanager)
DEFAULT_PAYLOAD='{
    "alerts": [
      {
        "annotations": {
          "description": "El Deployment mini-repo (demo-eda) no tiene pods disponibles a pesar de tener replicas deseadas >=1.",
          "summary": "mini-repo: despliegue sin réplicas disponibles"
        },
        "endsAt": "0001-01-01T00:00:00Z",
        "fingerprint": "00777cdb637e5577",
        "generatorURL": "https://console-openshift-console.apps-crc.testing/monitoring/graph?g0.expr=%28kube_deployment_spec_replicas%7Bdeployment%3D%22mini-repo%22%2Cnamespace%3D%22demo-eda%22%7D+%3E%3D+1%29+and+on+%28namespace%2C+deployment%29+%28kube_deployment_status_replicas_available%7Bdeployment%3D%22mini-repo%22%2Cnamespace%3D%22demo-eda%22%7D+%3C+2%29&g0.tab=1",
        "labels": {
          "alertname": "DeploymentDown",
          "container": "kube-rbac-proxy-main",
          "deployment": "mini-repo",
          "endpoint": "https-main",
          "job": "kube-state-metrics",
          "namespace": "demo-eda",
          "prometheus": "openshift-monitoring/k8s",
          "service": "kube-state-metrics",
          "severity": "critical"
        },
        "startsAt": "2025-11-13T05:01:09.187Z",
        "status": "firing"
      },
      {
        "annotations": {
          "description": "El target mini-repo no responde al endpoint /metrics.",
          "summary": "mini-repo no está siendo scrapeado"
        },
        "endsAt": null,
        "fingerprint": "af8659d679f2601c",
        "generatorURL": "https://console-openshift-console.apps-crc.testing/monitoring/graph?g0.expr=up%7Bnamespace%3D%22demo-eda%22%2Cservice%3D%22mini-repo%22%7D+%3D%3D+0&g0.tab=1",
        "labels": {
          "alertname": "TargetDown",
          "container": "app",
          "endpoint": "http",
          "instance": "10.217.0.122:8000",
          "job": "mini-repo",
          "namespace": "demo-eda",
          "pod": "mini-repo-54f8bbf9c8-nwchs",
          "prometheus": "openshift-user-workload-monitoring/user-workload",
          "service": "mini-repo",
          "severity": "critical"
        },
        "startsAt": "2025-11-13T04:59:09.187Z",
        "status": "resolved"
      }
    ],
    "commonAnnotations": {},
    "commonLabels": {
      "namespace": "demo-eda",
      "severity": "critical"
    },
    "externalURL": "https://console-openshift-console.apps-crc.testing/monitoring",
    "groupKey": "{}/{namespace=\"demo-eda\",severity=~\"warning|critical\"}:{namespace=\"demo-eda\"}",
    "groupLabels": {
      "namespace": "demo-eda"
    },
    "receiver": "demo-eda/mini-repo-amcfg/ansible-eda",
    "status": "firing",
    "truncatedAlerts": 0,
    "version": "4"
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

