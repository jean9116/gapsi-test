# 0001. Cloud Run como runtime de frontend, API, worker y batch

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
Hay que ejecutar un frontend React, una API Node.js, consumidores de eventos y procesos batch,
con tráfico de 100k–500k operaciones/día, picos de 2.000 usuarios concurrentes y un 30 % de crecimiento
anual. El equipo es pequeño y la aplicación todavía está en desarrollo.

## Decisión
- **Cloud Run services** para frontend (nginx con los estáticos), API y worker.
- **Cloud Run jobs + Cloud Scheduler** para el batch, programado o bajo demanda.
- Una imagen por componente, promovida sin reconstruir de dev a qa y prod.
- Salida a la VPC con **Direct VPC egress**, sin conectores serverless que pagar ni mantener.

Alternativas descartadas:
- **GKE Autopilot**: más control (sidecars, mallas de servicio, cargas con estado), pero a cambio de
  clúster, upgrades, manifiestos y políticas de red, con ~73 $/mes de tarifa de clúster por ambiente.
  Esta carga no lo necesita.
- **App Engine**: menos flexible con los contenedores y la red. Cloud Run es su sucesor natural.

## Consecuencias
- Escala a cero en dev y qa, y por petición en prod: no se paga capacidad ociosa salvo las
  instancias mínimas de prod (≈49 $/mes), que eliminan los arranques en frío.
- El autoescalado es horizontal y automático (`max_instances` por servicio). `max_instances`
  también limita las conexiones a la BD: `max_instances × pool por instancia` debe quedar por
  debajo de `max_connections`. En prod, la API va a 30 instancias con un pool de 8, lo que da 240
  conexiones frente a un máximo de 300.
- Límites a vigilar: 60 min por petición, 24 h por tarea de job y sistema de ficheros en memoria.
  Si un proceso los supera, se pasa a Batch o GKE.
