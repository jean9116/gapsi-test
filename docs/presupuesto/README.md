# Presupuesto

Estimación mensual y anual por ambiente para los años 1, 2 y 3, con un crecimiento del 30 %
anual. Se usan precios de lista en USD para us-central1, sin impuestos, consultados el
2026-10-14.

El cálculo es reproducible: `python3 docs/presupuesto/calcular.py` regenera `presupuesto.csv`,
con el detalle por partida, y `tablas.md`.

## Supuestos

| Concepto | DEV | QA | PROD |
|---|---|---|---|
| Peticiones API/mes | 0,5 M | 2 M | 15 M (500k operaciones/día, cota alta) |
| Peticiones frontend/mes | 0,2 M | 0,5 M | 5 M (mayoría servida por CDN) |
| Eventos Pub/Sub/mes | 0,1 M | 0,4 M | 3 M |
| Cloud SQL | db-g1-small zonal | 1 vCPU / 3,75 GiB zonal | 2 vCPU / 8 GiB HA regional |
| Disco BD | 10 GiB | 20 GiB | 50 GiB |
| Instancias mínimas Cloud Run | 0 | 0 | frontend 1, API 2, worker 1 |
| Salida CDN / API | 2 / 5 GiB | 10 / 20 GiB | 300 / 145 GiB |
| Ficheros en GCS | 5 GiB | 20 GiB | 100 GiB |
| Logs ingeridos | 3 GiB | 8 GiB | 42 GiB, retención 90 días |

- **Fijo**: capacidad reservada, que no cambia con el tráfico (Cloud SQL, instancias mínimas,
  balanceador, reglas de Armor, alertas). **Variable**: escala con el uso y crece ×1,3 el año 2 y
  ×1,69 el año 3.
- No se descuentan las capas gratuitas por cuenta de facturación, para quedar del lado
  conservador. Sí se descuentan las que son por proyecto (50 GiB de Logging) y las de CI (Cloud
  Build y Artifact Registry).
- Cloud SQL se mantiene en 2 vCPU los tres años. Con 845k operaciones/día en el año 3 (~10 op/s
  de media, ~100 en pico), una consulta típica de unos pocos ms deja margen. Se revisa con Query
  Insights; subir a 4 vCPU HA añade unos 200 $/mes.

## Resultado

| Ambiente | Año 1 $/mes | Año 1 $/año | Año 2 $/mes | Año 2 $/año | Año 3 $/mes | Año 3 $/año |
|---|--:|--:|--:|--:|--:|--:|
| DEV | 70,39 | 844,68 | 71,78 | 861,38 | 73,59 | 883,10 |
| QA | 102,40 | 1.228,80 | 106,27 | 1.275,20 | 111,29 | 1.335,53 |
| PROD | 396,35 | 4.756,20 | 428,78 | 5.145,31 | 476,13 | 5.713,56 |
| Shared (CI/CD) | 0,26 | 3,12 | 0,34 | 4,02 | 0,43 | 5,19 |
| **Total** | **569,40**|**6.832,80** | **607,16**|**7.285,92** | **661,45**|**7.937,38** |

**Total a 3 años: 22.056,10 USD** (precios de lista, sin impuestos ni descuentos).


#### DEV (año 1)

| Servicio | Concepto | Tipo | $/mes |
|---|---|---|--:|
| Cloud SQL | db-g1-small zonal | fijo | 25,55 |
| Cloud SQL | SSD 10 GiB | variable | 1,70 |
| Cloud SQL | backups ~5 GiB | variable | 0,40 |
| Cloud Run | tiempo activo (150 ms/petición, concurrencia efectiva 20) | variable | 0,12 |
| Cloud Run | peticiones | variable | 0,32 |
| Cloud Run Jobs | conciliación diaria 10 min + reportes semanal 30 min | variable | 0,53 |
| Load Balancer | 2 reglas de reenvío | fijo | 18,25 |
| Load Balancer | datos procesados ~8 GiB | variable | 0,06 |
| Cloud CDN | salida ~2 GiB + llenado + consultas | variable | 0,31 |
| Internet egress | respuestas de API ~5 GiB | variable | 0,60 |
| Cloud Armor | política + 7 reglas | fijo | 12,00 |
| Cloud Armor | peticiones evaluadas | variable | 0,41 |
| Cloud NAT | IP + pasarela (instancias medias conectadas) | fijo | 4,67 |
| Cloud NAT | datos ~1 GiB | variable | 0,04 |
| Pub/Sub | ~0 GiB de mensajes | variable | 0,01 |
| Cloud Storage | 5 GiB Standard + operaciones | variable | 0,14 |
| Secret Manager | 3 secretos activos | fijo | 0,18 |
| Cloud Monitoring | 14 condiciones de alerta | fijo | 4,90 |
| Cloud Scheduler | 2 jobs programados | fijo | 0,20 |
| Cloud Logging | ingesta y retención | variable | 0,00 |

#### QA (año 1)

| Servicio | Concepto | Tipo | $/mes |
|---|---|---|--:|
| Cloud SQL | 1 vCPU / 3.75 GiB zonal | fijo | 49,31 |
| Cloud SQL | SSD 20 GiB | variable | 3,40 |
| Cloud SQL | backups ~15 GiB | variable | 1,20 |
| Cloud Run | tiempo activo (150 ms/petición, concurrencia efectiva 20) | variable | 0,48 |
| Cloud Run | peticiones | variable | 1,16 |
| Cloud Run Jobs | conciliación diaria 10 min + reportes semanal 30 min | variable | 0,53 |
| Load Balancer | 2 reglas de reenvío | fijo | 18,25 |
| Load Balancer | datos procesados ~34 GiB | variable | 0,27 |
| Cloud CDN | salida ~10 GiB + llenado + consultas | variable | 1,18 |
| Internet egress | respuestas de API ~20 GiB | variable | 2,40 |
| Cloud Armor | política + 7 reglas | fijo | 12,00 |
| Cloud Armor | peticiones evaluadas | variable | 1,58 |
| Cloud NAT | IP + pasarela (instancias medias conectadas) | fijo | 4,67 |
| Cloud NAT | datos ~2 GiB | variable | 0,09 |
| Pub/Sub | ~1 GiB de mensajes | variable | 0,06 |
| Cloud Storage | 20 GiB Standard + operaciones | variable | 0,54 |
| Secret Manager | 3 secretos activos | fijo | 0,18 |
| Cloud Monitoring | 14 condiciones de alerta | fijo | 4,90 |
| Cloud Scheduler | 2 jobs programados | fijo | 0,20 |
| Cloud Logging | ingesta y retención | variable | 0,00 |

#### PROD (año 1)

| Servicio | Concepto | Tipo | $/mes |
|---|---|---|--:|
| Cloud SQL | 2 vCPU / 8 GiB HA regional | fijo | 202,36 |
| Cloud SQL | SSD 50 GiB (×2 HA) | variable | 17,00 |
| Cloud SQL | backups ~50 GiB | variable | 4,00 |
| Cloud Run | instancias mínimas (frontend 1, api 2, worker 1) | fijo | 49,28 |
| Cloud Run | tiempo activo (150 ms/petición, concurrencia efectiva 20) | variable | 3,83 |
| Cloud Run | peticiones | variable | 9,20 |
| Cloud Run Jobs | conciliación diaria 10 min + reportes semanal 30 min | variable | 0,53 |
| Load Balancer | 2 reglas de reenvío | fijo | 18,25 |
| Load Balancer | datos procesados ~473 GiB | variable | 3,78 |
| Cloud CDN | salida ~300 GiB + llenado + consultas | variable | 27,90 |
| Internet egress | respuestas de API ~145 GiB | variable | 17,40 |
| Cloud Armor | política + 7 reglas | fijo | 12,00 |
| Cloud Armor | peticiones evaluadas | variable | 12,00 |
| Cloud NAT | IP + pasarela (instancias medias conectadas) | fijo | 8,76 |
| Cloud NAT | datos ~10 GiB | variable | 0,45 |
| Pub/Sub | ~11 GiB de mensajes | variable | 0,44 |
| Cloud Storage | 100 GiB Standard + operaciones | variable | 3,05 |
| Secret Manager | 3 secretos activos | fijo | 0,18 |
| Cloud Monitoring | 14 condiciones de alerta | fijo | 4,90 |
| Cloud Scheduler | 2 jobs programados | fijo | 0,20 |
| Cloud Logging | ingesta y retención | variable | 0,84 |

## Dónde está el dinero y cómo bajarlo

| Palanca | Ahorro estimado | Cuándo aplicarla |
|---|---|---|
| **CUD de Cloud SQL** en prod: compromiso de vCPU y RAM a 1 año (−25 %) o a 3 años (−52 %) | ~50 $/mes (1 año) o ~105 $/mes (3 años) | En cuanto el tamaño de prod esté validado con tráfico real |
| **CUD flexible** (compute, incluye Cloud Run) | ~17 % de lo comprometido | Cuando el gasto base de Cloud Run sea estable |
| Apagar QA fuera de horario: `activation_policy = NEVER` en Cloud SQL | ~25 $/mes | Si QA solo se usa en horario laboral |
| Bajar la instancia mínima de la API de 2 a 1 en prod | ~13 $/mes | Si se aceptan arranques en frío tras inactividad |
| Muestreo de logs del balanceador al 50 % en prod | Evita superar los 50 GiB gratuitos en el año 3 | Cuando el volumen de logs se acerque al límite |

Prod se lleva ~70 % del total y, dentro de prod, **Cloud SQL HA es ~56 %**. La HA es el precio de
cumplir «sin puntos únicos de falla» en la base de datos. Sin ella, ahorraríamos unos 110 $/mes a
cambio de 5–10 min de caída en un fallo de zona.

## Controles de gasto ya incluidos

- Presupuesto por proyecto en Cloud Billing (bootstrap): avisos al 50 %, 90 % y 100 % del gasto
  real y al 100 % del previsto. Los importes son DEV 150 $, QA 250 $, PROD 900 $ y shared 30 $
  (variable `environments`).
- `max_instances` en cada servicio: limita tanto el gasto como las conexiones a la BD.
- Ciclo de vida en GCS: Nearline a los 90 días y borrado de versiones antiguas. Limpieza de
  imágenes sin tag en Artifact Registry.
- Etiquetas `app`, `env`, `component` y `managed-by` en todos los recursos, para el desglose en
  la exportación de facturación.

## Precios de lista usados

| Servicio | Precio |
|---|---|
| Cloud SQL Enterprise | vCPU 0,0413 $/h; RAM 0,007 $/GiB-h; HA ×2. SSD 0,17 $/GiB-mes (HA 0,34). Backups 0,08 $/GiB-mes. db-g1-small 0,035 $/h |
| Cloud Run (facturación por petición) | CPU 0,000024 $/vCPU-s; RAM 0,0000025 $/GiB-s; 0,40 $/M peticiones. Instancia mínima inactiva: 0,0000025 $/vCPU-s y $/GiB-s |
| Cloud Run Jobs | CPU 0,000018 $/vCPU-s; RAM 0,000002 $/GiB-s |
| Load Balancer externo | 0,025 $/h (primeras 5 reglas); 0,008 $/GiB procesado |
| Cloud CDN | 0,08 $/GiB de salida en Norteamérica; 0,01 $/GiB de llenado; 0,0075 $ por 10k consultas |
| Cloud Armor (Standard) | 5 $/política/mes; 1 $/regla/mes; 0,75 $/M peticiones |
| Cloud NAT | 0,0014 $/h por instancia (máx. 0,044 $/h); 0,045 $/GiB; IP 0,005 $/h |
| Salida a Internet (Premium) | 0,12 $/GiB |
| Pub/Sub | 40 $/TiB |
| Cloud Storage Standard | 0,02 $/GiB-mes; clase A 0,05 $ y clase B 0,004 $ por 10k operaciones |
| Secret Manager | 0,06 $/versión activa |
| Cloud Logging | 0,50 $/GiB (50 GiB/proyecto gratis); retención extra 0,01 $/GiB-mes |
| Cloud Monitoring | 0,35 $/condición de alerta/mes; uptime checks 0,30 $/1k (1M gratis) |
| Cloud Scheduler | 0,10 $/job/mes (3 gratis por cuenta) |
| Artifact Registry | 0,10 $/GiB-mes (0,5 GiB gratis) |
| Artifact Analysis (desactivado) | 0,26 $/imagen escaneada |
| Cloud Build | e2-standard-2 0,006 $/min (2.500 min/mes gratis) |

Fuentes: páginas oficiales de precios de cada servicio en cloud.google.com/<servicio>/pricing y
la calculadora de GCP.
