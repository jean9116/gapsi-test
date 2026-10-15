# 0006. Balanceador global con Cloud Armor y CDN; servicios sin entrada pública directa

- Estado: aceptada
- Fecha: 2026-10-14

## Contexto
Hay que separar los componentes públicos de los privados, proteger la entrada y servir el
frontend con buena latencia.

## Decisión
- **Load balancer HTTPS externo global** como única entrada pública:
  - `/api/*` va a la API y el resto, al frontend;
  - certificado gestionado por Google, política TLS MODERN (≥ 1.2) y redirección de 80 a 443.
- Frontend y API con `ingress = INTERNAL_AND_CLOUD_LOAD_BALANCING`: la URL `run.app` no es accesible
  desde Internet. El worker es `INTERNAL_ONLY`.
- **Cloud Armor**:
  - reglas WAF preconfiguradas (SQLi, XSS, LFI, RCE, Log4j);
  - límite por IP, que responde 429 al superarlo;
  - protección adaptativa L7.
- **Cloud CDN** solo para el frontend. La API no se cachea.
- **VPC propia**:
  - subred de aplicación con Private Google Access;
  - Cloud NAT para la salida a Internet (integraciones), con IP de salida estable;
  - firewall que deniega toda entrada por defecto;
  - flow logs en prod.
- Sin dominio propio se usa `<ip>.sslip.io`, válido para el certificado gestionado. Con dominio,
  se define `domain` y un registro A.

## Consecuencias
- Coste fijo del borde: ≈30 $/mes por ambiente (LB 18,25 + Armor 12). Es el precio de tener WAF y
  un punto de entrada único.
- El certificado gestionado tarda entre 15 y 60 min en emitirse después del primer apply.
