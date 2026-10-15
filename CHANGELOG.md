# Changelog

Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y versionado
[SemVer](https://semver.org/lang/es/).

## [Sin publicar]

## [0.1.0] - 2026-10-14

### Añadido
- `terraform/bootstrap`: proyectos shared/dev/qa/prod, bucket de estado, Artifact Registry,
  service accounts de CI/CD, triggers de Cloud Build y presupuestos.
- `terraform/platform` con 9 módulos (network, database, iam, storage, pubsub, run-service,
  run-job, edge, observability) y tfvars por ambiente.
- Tests de plan (`terraform test`) de los tres ambientes con provider simulado.
- Pipelines de Cloud Build: plan en PR, apply por ambiente, build/escaneo/despliegue de
  aplicaciones y promoción del mismo digest.
- Aplicación de ejemplo (frontend, api, worker, batch) para probar la infraestructura.
- README, ADRs 0001–0007 y presupuesto reproducible a 3 años.
