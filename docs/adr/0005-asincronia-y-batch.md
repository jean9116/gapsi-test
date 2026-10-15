# 0005. Pub/Sub con push al worker y Cloud Run jobs para el batch

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
La API debe publicar eventos y trabajos para procesarlos después, e intercambiar información con
aplicaciones externas (por ejemplo, un ERP). Además hay procesos programados.

## Decisión
- **Pub/Sub**: un topic por tipo de evento (`pedidos`, `entregas`, `integraciones-entrada`,
  `integraciones-salida`).
  - Las suscripciones **push** con token OIDC entregan al worker, que tiene ingress interno y
    solo admite como invoker a la SA `pubsub-push`.
  - Reintentos con backoff exponencial y, tras 5 intentos, **dead-letter topic** con alerta.
- **Aplicaciones externas**: cada una tiene su SA (`sa-ext-<app>`), con permiso de publicar solo en
  sus topics de entrada y una suscripción **pull** propia para los de salida.
- **Batch**: Cloud Run jobs con Cloud Scheduler (OAuth). Cada scheduler solo puede invocar su
  job, y hay alerta si una ejecución falla.

Alternativas descartadas:
- **Cloud Tasks**: útil para tareas dirigidas a un endpoint con control de ritmo, pero no tiene
  fan-out ni consumidores externos.
- **Eventarc**: añade una capa encima de Pub/Sub sin aportar nada a este caso.

## Consecuencias
- La entrega es al menos una vez, así que los handlers deben ser **idempotentes** (clave de
  evento).
- Si el worker cae, los mensajes esperan en la suscripción hasta 7 días, sin perderse. La alerta
  de backlog avisa antes.
