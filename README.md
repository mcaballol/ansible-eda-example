# Ansible EDA Example - Mini-Repo

Este proyecto demuestra cómo integrar **Ansible Event-Driven Ansible (EDA)** con **Prometheus** y **Alertmanager** en OpenShift para reaccionar automáticamente a alertas mediante playbooks de Ansible.

## Descripción

La aplicación `mini-repo` es una aplicación Flask simple que:
- Expone métricas Prometheus en `/metrics`
- Proporciona un endpoint de salud en `/healthz`
- Simula trabajo con posibilidad de errores en `/do_work` (10% de probabilidad de error)

Cuando Prometheus detecta problemas (definidos en `PrometheusRule`), Alertmanager envía las alertas a Ansible EDA mediante un webhook, que ejecuta playbooks para realizar acciones automáticas.

## Arquitectura

```
Prometheus (UWM) → Alertmanager (UWM) → Ansible EDA Webhook → Playbook
```

## Estructura del Proyecto

```
ansible-eda-example/
├── app.py                          # Aplicación Flask con métricas Prometheus
├── Containerfile                   # Imagen de contenedor para la app
├── requirements.txt                # Dependencias Python
├── playbooks/
│   └── handle_alert.yml           # Playbook que reacciona a alertas
├── rulebooks/
│   └── rulebook.yml               # Configuración de Ansible EDA
└── openshift/
    ├── 00-namespace.yaml          # Namespace demo-eda
    ├── 10-deployment.yaml         # Deployment de mini-repo
    ├── 20-service.yaml            # Service para mini-repo
    ├── 30-route.yaml              # Route para acceso externo
    ├── 40-servicemonitor.yaml     # ServiceMonitor para Prometheus
    ├── 50-prometheusrule.yaml     # Reglas de alertas Prometheus
    └── 60-alertmanagerconfig.yaml # Configuración de Alertmanager
```

## Requisitos Previos

1. **OpenShift Cluster** con acceso administrativo
2. **User Workload Monitoring (UWM)** habilitado en el cluster
3. **Podman** o **Docker** instalado
4. **Ansible EDA** ejecutándose y accesible desde el cluster
5. Acceso a un registry de contenedores (Quay.io, Docker Hub, etc.)

## Configuración Inicial

### 1. Habilitar User Workload Monitoring (si es necesario)

Si tu cluster no tiene User Workload Monitoring activo, un administrador debe habilitarlo editando el ConfigMap `cluster-monitoring-config` en el namespace `openshift-monitoring`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-monitoring-config
  namespace: openshift-monitoring
data:
  config.yaml: |
    enableUserWorkload: true
```

### 2. Construir y Publicar la Imagen

```bash
# Construir la imagen
podman build -t <TU_REGISTRY>/mini-repo:latest .

# Publicar la imagen
podman push <TU_REGISTRY>/mini-repo:latest
```

**Nota:** Reemplaza `<TU_REGISTRY>` con tu registry (ej: `quay.io/tu-usuario` o `docker.io/tu-usuario`).

### 3. Actualizar la Referencia de la Imagen

Antes de desplegar, actualiza el archivo `openshift/10-deployment.yaml` para usar tu imagen:

```yaml
image: <TU_REGISTRY>/mini-repo:latest
```

### 4. Configurar Ansible EDA

1. **Actualizar el token en `rulebooks/rulebook.yml`:**
   ```yaml
   token: "tu-token-seguro-aqui"
   ```

2. **Actualizar la URL del webhook en `openshift/60-alertmanagerconfig.yaml`:**
   ```yaml
   url: "https://tu-eda-instance.com/webhook/mini-repo"
   ```

## Despliegue en OpenShift

### 1. Crear el Namespace

```bash
oc apply -f openshift/00-namespace.yaml
```

### 2. Desplegar la Aplicación

```bash
# Desplegar aplicación y servicios
oc apply -f openshift/10-deployment.yaml -f openshift/20-service.yaml -f openshift/30-route.yaml

# Configurar monitoreo
oc apply -f openshift/40-servicemonitor.yaml -f openshift/50-prometheusrule.yaml -f openshift/60-alertmanagerconfig.yaml
```

### 3. Verificar el Despliegue

1. **Verificar que el Deployment está corriendo:**
   ```bash
   oc get pods -n demo-eda
   ```

2. **Obtener la URL de la Route:**
   ```bash
   oc get route -n demo-eda
   ```

3. **Verificar el endpoint de salud:**
   ```bash
   curl -k https://<route>/healthz
   ```
   Debería responder: `ok`

4. **Verificar métricas (desde dentro del cluster):**
   ```bash
   curl http://mini-repo.demo-eda.svc:8000/metrics
   ```

5. **Verificar en Prometheus (UWM):**
   - Accede a la consola de Prometheus de User Workload Monitoring
   - Verifica que el target `ServiceMonitor/mini-repo` aparece en Status → Targets
   - Deberías ver métricas como `app_requests_ok_total` y `app_requests_error_total`

### 4. Probar las Alertas

Para disparar la alerta `HighErrorRate`, genera carga en el endpoint `/do_work`:

```bash
# Desde fuera del cluster
ROUTE=$(oc get route mini-repo -n demo-eda -o jsonpath='{.spec.host}')
for i in {1..100}; do
  curl -k https://$ROUTE/do_work
  sleep 0.5
done
```

Con ~10% de probabilidad de error, deberías generar suficientes errores para activar la alerta después de 5 minutos.

## Alertas Configuradas

El proyecto incluye dos alertas definidas en `50-prometheusrule.yaml`:

### 1. TargetDown
- **Severidad:** Critical
- **Condición:** El target `mini-repo` no está siendo scrapeado (`up == 0`)
- **Duración:** 1 minuto

### 2. HighErrorRate
- **Severidad:** Warning
- **Condición:** Tasa de error > 5% durante 5 minutos, con mínimo de 10 requests/minuto
- **Duración:** 5 minutos

## Flujo de Eventos

1. **Prometheus** scrapea métricas de `mini-repo` cada 15 segundos
2. Cuando se cumple una condición de alerta, **Prometheus** la evalúa
3. Si la alerta se mantiene durante el tiempo especificado (`for`), se envía a **Alertmanager**
4. **Alertmanager** (UWM) consulta `AlertmanagerConfig` en el namespace `demo-eda`
5. **Alertmanager** envía el webhook a **Ansible EDA** con el payload de la alerta
6. **Ansible EDA** ejecuta el playbook `handle_alert.yml` con la información de la alerta
7. El playbook puede realizar acciones automáticas (ej: reiniciar el deployment)

## Acciones Automáticas

El playbook `playbooks/handle_alert.yml` incluye ejemplos de acciones:

- **Log de alertas:** Registra información sobre la alerta recibida
- **Reinicio automático:** Si es `TargetDown` crítico, reinicia el deployment `mini-repo`

Puedes extender este playbook para:
- Escalar el deployment
- Crear tickets en sistemas externos
- Enviar notificaciones
- Ejecutar remediaciones específicas

## Notas Importantes

### Seguridad

⚠️ **Importante:** En producción:
- Elimina `insecureSkipVerify: true` del `AlertmanagerConfig` y configura TLS válido
- Protege el webhook de EDA con autenticación (token/certificados)
- Usa certificados válidos para todas las comunicaciones

### User Workload Monitoring

- `AlertmanagerConfig` se procesa por el **Alertmanager de UWM**; el Alertmanager del cluster (infraestructura) no toma objetos de proyectos de usuario
- El namespace debe tener la etiqueta `openshift.io/user-monitoring: "true"` (ya incluida en `00-namespace.yaml`)
- El `ServiceMonitor` debe tener el label `release: user-workload` si tu operador lo requiere

### Troubleshooting

1. **No aparecen métricas en Prometheus:**
   - Verifica que el `ServiceMonitor` tiene el label correcto
   - Verifica que UWM está habilitado
   - Revisa los logs de Prometheus UWM

2. **Las alertas no se envían a EDA:**
   - Verifica que el `AlertmanagerConfig` está aplicado correctamente
   - Verifica la conectividad desde el cluster a la instancia de EDA
   - Revisa los logs de Alertmanager UWM

3. **El webhook no llega a EDA:**
   - Verifica la URL en `AlertmanagerConfig`
   - Verifica el token si está configurado
   - Revisa los logs de Ansible EDA

## Referencias

- [Ansible Event-Driven Ansible Documentation](https://ansible.readthedocs.io/projects/rulebook/)
- [OpenShift User Workload Monitoring](https://docs.openshift.com/container-platform/latest/monitoring/enabling-monitoring-for-user-defined-projects.html)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)


