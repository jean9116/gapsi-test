# 0003. Un proyecto por ambiente y un único root de Terraform

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
Hay tres ambientes, que deben usar la misma definición de infraestructura con configuraciones
distintas y estar separados.

## Decisión
- **Un proyecto GCP por ambiente**, `pprov-{dev,qa,prod}-<sufijo>`, más `pprov-shared-<sufijo>` para
  el estado, Artifact Registry y CI/CD. El proyecto es el límite de IAM, cuotas, facturación y
  daño en caso de error.
- **Un solo root**, `terraform/platform`, compuesto por módulos propios en `terraform/modules`. Lo
  que cambia por ambiente vive en `environments/<env>/terraform.tfvars`, y lo común en
  `common.tfvars`.
- **Estado separado por ambiente**: bucket GCS versionado con el prefijo `platform/<env>`
  (`environments/<env>/backend.hcl`).
- `terraform/bootstrap` crea los proyectos, el estado, el registro, las SAs de CI y los
  presupuestos. Lo ejecuta una persona una sola vez.

Alternativas descartadas:
- **Workspaces de Terraform**: comparten backend y credenciales, y es fácil aplicar sobre el
  ambiente equivocado.
- **Un directorio por ambiente que llama a los módulos**: duplica el cableado y permite que los
  ambientes diverjan sin querer.
- **Terragrunt**: otra herramienta más para un problema que se resuelve con tfvars y backend.

## Consecuencias
- Si algo existe en prod, existe en dev; solo cambia el tamaño. Las diferencias se ven en un
  único fichero.
- Sin organización de GCP (cuenta personal), no hay carpetas ni políticas de organización: el IAM
  se da proyecto a proyecto. Con organización, se pasa `org_id`/`folder_id` al bootstrap y se
  añaden políticas como `iam.disableServiceAccountKeyCreation` o `sql.restrictPublicIp`.
