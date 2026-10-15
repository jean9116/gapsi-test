# 0002. Cloud SQL PostgreSQL privado con conector e IAM

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
Hace falta una base de datos relacional administrada que no esté expuesta a Internet, con
backups, recuperación a un punto en el tiempo y alta disponibilidad en producción.

## Decisión
- **Cloud SQL for PostgreSQL 18**, edición Enterprise.
- **Solo IP privada**, por Private Service Access: rango /20 reservado en la VPC y
  `ipv4_enabled = false`.
- `connector_enforcement = REQUIRED`: solo se conecta por el Cloud SQL Connector o el Auth Proxy, con
  mTLS y autorización IAM (`roles/cloudsql.client`). `ssl_mode = ENCRYPTED_ONLY`.
- **Autenticación IAM** para las SAs de api, worker y batch, sin contraseñas. El usuario
  `app_admin`, que solo usa el job de migraciones, tiene una contraseña generada como valor
  *write-only*/efímero: va a Secret Manager y **nunca queda en el estado de Terraform**.
- Prod: **HA regional**, con standby síncrono en otra zona y failover automático (~60 s). 30
  backups diarios en la multirregión `us`, PITR de 7 días, `deletion_protection` y ventana de
  mantenimiento fijada.
- Dev y qa: zonal, con menos backups y sin protección contra borrado.

Alternativas descartadas:
- **AlloyDB**: más rendimiento, pero cuesta como mínimo ~3 veces más. No lo justifica esta carga.
- **IP pública con redes autorizadas**: deja expuesta la superficie de red.
- **Réplica de lectura entre regiones**: se descarta de momento por coste, ~200 $/mes más. Es la
  siguiente medida si el negocio pide un RPO de minutos ante la caída de una región entera.

## Consecuencias
- RPO: segundos ante un fallo de zona (réplica síncrona) y unos minutos con PITR ante errores
  lógicos. Ante la pérdida de la región, el RPO es el último backup diario; el RTO es restaurar
  en otra región, del orden de 1 h. Ver «Recuperación» en el README.
- Escalar verticalmente (`db.tier`) reinicia la instancia, unos minutos en HA. Hay que hacerlo
  dentro de la ventana de mantenimiento.
