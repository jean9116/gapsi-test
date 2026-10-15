# 0004. CI/CD con Cloud Build y promoción de imágenes, sin Cloud Deploy

- Estado: aceptada (sustituye al plan inicial, que usaba Cloud Deploy)
- Fecha: 2026-10-14

## Contexto
El pipeline debe usar servicios de GCP. Terraform ya define por completo los servicios de Cloud
Run: recursos, escalado, red, secretos y variables.

## Decisión
- **Cloud Build**, con triggers declarados en `terraform/bootstrap/cicd.tf` y repositorio de
  GitHub conectado en 2.ª generación.
- **Infraestructura**:
  - En cada PR: `fmt`, `validate`, `tflint`, `checkov`, `terraform test` y `plan` de los tres
    ambientes, con una SA de solo lectura.
  - Al hacer merge: un trigger de `apply` por ambiente, cada uno con su SA limitada a su proyecto.
    qa y prod requieren **aprobación manual** en Cloud Build.
- **Aplicación**:
  - Al hacer merge se construyen las imágenes una sola vez (tag = SHA, inmutable), se escanean
    con Trivy, se suben y se despliegan en dev: migraciones, servicios, jobs, smoke test y
    rollback.
  - La promoción a qa y prod es manual, del **mismo digest**. Prod lleva aprobación.
- El pipeline solo cambia la **imagen**. Terraform ignora ese campo (`ignore_changes`) y sigue
  siendo dueño de todo lo demás.

Alternativa descartada:
- **Cloud Deploy**: aplica la especificación completa del servicio (`service.yaml`) en cada
  release. Duplicaría la configuración de Terraform y las dos herramientas acabarían pisándose.
  Tendría sentido con canary/blue-green gestionado o con muchos servicios. Hoy, los canarios se
  pueden hacer con `--no-traffic` y `update-traffic` en Cloud Run.

## Consecuencias
- Sin claves de servicio: Cloud Build se ejecuta como SAs del proyecto shared, sin JSON ni
  federación de identidades.
- La SA del pipeline de aplicaciones (`sa-cicd-app`) solo puede publicar revisiones y ejecutar
  jobs (`run.developer`) y actuar como las SAs de runtime. No toca IAM, red ni BD.
- Coste: dentro de los 2.500 min/mes gratuitos con la máquina por defecto.
