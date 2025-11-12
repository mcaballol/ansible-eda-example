#!/usr/bin/env python3
"""
Script para enviar eventos al endpoint de Ansible EDA Event Stream
Uso: python3 send-event.py [--payload payload_file.json] [--url URL]
"""

import json
import sys
import argparse
import requests
from typing import Dict, Any

# URL por defecto
DEFAULT_URL = "https://aap-aap.apps-crc.testing/eda-event-streams/api/eda/v1/external_event_stream/703efa48-f7b6-4229-95fe-53db03f5b60a/post/"

# Payload por defecto (simula una alerta de Prometheus/Alertmanager)
DEFAULT_PAYLOAD = {
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
    "endsAt": None
}


def load_payload(file_path: str) -> Dict[Any, Any]:
    """Carga un payload desde un archivo JSON"""
    with open(file_path, 'r') as f:
        return json.load(f)


def send_event(url: str, payload: Dict[Any, Any], verify_ssl: bool = False) -> None:
    """Envía un evento al endpoint de EDA"""
    headers = {
        "Content-Type": "application/json",
        "Authorization": "token"
    }
    
    print(f"Enviando evento a: {url}")
    print(f"Payload:")
    print(json.dumps(payload, indent=2))
    print()
    
    try:
        response = requests.post(
            url,
            json=payload,
            headers=headers,
            verify=verify_ssl,
            timeout=30
        )
        
        print(f"Respuesta HTTP: {response.status_code}")
        print(f"Cuerpo de la respuesta:")
        
        try:
            print(json.dumps(response.json(), indent=2))
        except ValueError:
            print(response.text)
        
        response.raise_for_status()
        print("\n✅ Evento enviado exitosamente")
        
    except requests.exceptions.RequestException as e:
        print(f"\n❌ Error al enviar el evento: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Envía eventos al endpoint de Ansible EDA Event Stream"
    )
    parser.add_argument(
        "--payload",
        type=str,
        help="Archivo JSON con el payload del evento"
    )
    parser.add_argument(
        "--url",
        type=str,
        default=DEFAULT_URL,
        help=f"URL del endpoint (default: {DEFAULT_URL})"
    )
    parser.add_argument(
        "--verify-ssl",
        action="store_true",
        help="Verificar certificados SSL (default: False)"
    )
    
    args = parser.parse_args()
    
    # Cargar payload
    if args.payload:
        payload = load_payload(args.payload)
    else:
        payload = DEFAULT_PAYLOAD
    
    # Enviar evento
    send_event(args.url, payload, verify_ssl=args.verify_ssl)


if __name__ == "__main__":
    main()

