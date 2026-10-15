#!/usr/bin/env bash
# Despliega una versión (tag inmutable) en un ambiente:
#   1. resuelve el tag a digest (lo desplegado es exactamente lo escaneado);
#   2. ejecuta las migraciones con el job <app>-<env>-migrate y espera a que acaben;
#   3. publica nuevas revisiones de worker, api y frontend (solo cambia la imagen: el resto es de Terraform);
#   4. actualiza la imagen de los jobs batch;
#   5. smoke test contra el balanceador; si falla, devuelve el tráfico a la revisión anterior.
set -euo pipefail

PROJECT=$1 REGION=$2 ENV=$3 REGISTRY=$4 TAG=$5
APP=${APP:-pprov}
NAME="${APP}-${ENV}"
[[ -n "$TAG" ]] || { echo "Falta el tag (_TAG = SHA corto)"; exit 1; }

gc() { gcloud --project="$PROJECT" --quiet "$@"; }

digest() {
  local ref
  ref=$(gcloud artifacts docker images describe "${REGISTRY}/$1:${TAG}" --format='value(image_summary.digest)')
  echo "${REGISTRY}/$1@${ref}"
}

declare -A IMG
for c in frontend api worker batch; do IMG[$c]=$(digest "$c"); echo "$c -> ${IMG[$c]}"; done

echo "== Migraciones"
gc run jobs update "${NAME}-migrate" --region="$REGION" --image="${IMG[api]}"
gc run jobs execute "${NAME}-migrate" --region="$REGION" --wait

declare -A PREV
for s in worker api frontend; do
  PREV[$s]=$(gc run services describe "${NAME}-${s}" --region="$REGION" --format='value(status.latestReadyRevisionName)')
done

rollback() {
  echo "!! Smoke test fallido: vuelta a las revisiones anteriores"
  for s in worker api frontend; do
    [[ -n "${PREV[$s]}" ]] && gc run services update-traffic "${NAME}-${s}" --region="$REGION" --to-revisions="${PREV[$s]}=100"
  done
  exit 1
}

echo "== Servicios"
for s in worker api frontend; do
  # Solo la imagen: etiquetas, recursos y variables son de Terraform (ignore_changes en la imagen).
  gc run services update "${NAME}-${s}" --region="$REGION" --image="${IMG[$s]}"
  gc run services update-traffic "${NAME}-${s}" --region="$REGION" --to-latest
done

echo "== Jobs batch"
for j in $(gc run jobs list --region="$REGION" --format='value(metadata.name)' | grep "^${NAME}-" | grep -v -- "-migrate$"); do
  gc run jobs update "$j" --region="$REGION" --image="${IMG[batch]}"
done

echo "== Smoke test"
URL=$(gc run services describe "${NAME}-api" --region="$REGION" --format=json | python3 -c 'import sys,json;e=json.load(sys.stdin)["spec"]["template"]["spec"]["containers"][0]["env"];print(next(x["value"] for x in e if x["name"]=="PUBLIC_URL"))')
# -k: el certificado gestionado puede seguir aprovisionándose tras el primer apply; aquí se
# comprueba enrutado y aplicación. La validez del certificado la vigila el uptime check.
for path in /api/healthz /; do
  curl -fsSk --retry 6 --retry-delay 10 --retry-all-errors -o /dev/null -w "$path %{http_code}\n" "${URL}${path}" || rollback
done
echo "OK: ${ENV} en ${TAG}"
