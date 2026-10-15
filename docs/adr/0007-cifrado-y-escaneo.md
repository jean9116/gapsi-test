# 0007. Cifrado gestionado por Google y escaneo de imágenes con Trivy

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
checkov recomienda claves propias (CMEK/CSEK) y Artifact Registry ofrece escaneo automático de
vulnerabilidades.

## Decisión
- **Cifrado en reposo gestionado por Google** (AES-256) en Cloud SQL, GCS, Pub/Sub, Artifact
  Registry y Secret Manager. Las excepciones están documentadas en `.checkov.yaml`.
- **Trivy en el pipeline**: escanea antes del push y para el despliegue si hay vulnerabilidades
  CRITICAL con parche.
- El escaneo automático de Artifact Analysis queda **desactivado**: cuesta 0,26 $ por imagen
  subida, unos 40 $/mes con 4 imágenes por merge, y duplica a Trivy.

## Consecuencias
- Si un requisito de cumplimiento (PCI-DSS, contratos) exige CMEK:
  - crear Cloud KMS (~0,06 $/clave/mes más operaciones);
  - añadir `encryption_key_name` a cada recurso;
  - dar a los agentes de servicio `cryptoKeyEncrypterDecrypter`.
- Trivy no vuelve a escanear imágenes que ya están desplegadas. Para detectar CVEs nuevas en
  prod, se programa un escaneo semanal o se activa Artifact Analysis solo en el repositorio de
  prod.
