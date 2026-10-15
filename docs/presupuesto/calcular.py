#!/usr/bin/env python3
"""Presupuesto de la plataforma por ambiente y año.

Precios de lista en USD, us-central1, consultados el 2026-10-14 en las páginas oficiales de
GCP (ver precios.md). Ejecutar: python3 docs/presupuesto/calcular.py
Genera presupuesto.csv y tablas.md (tablas para pegar en README.md) junto a este script.

Criterio:
- Partidas "fijas": capacidad reservada (Cloud SQL, instancias mínimas, LB, reglas, alertas).
- Partidas "variables": dependen del tráfico/datos y crecen un 30 % anual (×1,3 y ×1,69).
- Las capas gratuitas por cuenta de facturación NO se descuentan (conservador), salvo las que
  son por proyecto (Logging: 50 GiB/proyecto) y las de CI (Cloud Build, Artifact Registry).
"""
import csv
from pathlib import Path

H = 730            # horas/mes
S = H * 3600       # segundos/mes
GROWTH = {1: 1.0, 2: 1.3, 3: 1.69}

P = {  # precios de lista
    "sql_vcpu_h": 0.0413, "sql_gib_h": 0.007, "sql_ssd": 0.17, "sql_backup": 0.08,
    "sql_g1_small_h": 0.035,
    "run_cpu": 0.000024, "run_mem": 0.0000025, "run_idle": 0.0000025, "run_req_m": 0.40,
    "job_cpu": 0.000018, "job_mem": 0.000002,
    "lb_rule_h": 0.025, "lb_gib": 0.008,
    "cdn_gib": 0.08, "cdn_fill": 0.01, "cdn_lookup_10k": 0.0075,
    "armor_policy": 5.0, "armor_rule": 1.0, "armor_req_m": 0.75,
    "nat_vm_h": 0.0014, "nat_gib": 0.045, "ip_h": 0.005,
    "egress_gib": 0.12,
    "pubsub_tib": 40.0,
    "gcs_std": 0.02, "gcs_a_10k": 0.05, "gcs_b_10k": 0.004,
    "secret_ver": 0.06, "log_gib": 0.50, "log_free": 50, "log_ret": 0.01,
    "alert_cond": 0.35, "scheduler_job": 0.10, "ar_gib": 0.10,
}

# Supuestos de uso del año 1 por ambiente. prod: 500k operaciones/día (cota alta) ≈ 15M peticiones
# de API al mes; 20k usuarios registrados, 2.000 concurrentes.
ENV = {
    "dev": dict(sql="g1-small", sql_ha=False, disk=10, backup_gib=5,
                api_req_m=0.5, fe_req_m=0.2, events_m=0.1, run_min={}, api_mem=0.5, worker_mem=0.5,
                cdn_gib=2, api_egress_gib=5, nat_avg_inst=1, nat_gib=1,
                gcs_gib=5, log_gib=3, log_retention=30),
    "qa": dict(sql=(1, 3.75), sql_ha=False, disk=20, backup_gib=15,
               api_req_m=2, fe_req_m=0.5, events_m=0.4, run_min={}, api_mem=0.5, worker_mem=0.5,
               cdn_gib=10, api_egress_gib=20, nat_avg_inst=1, nat_gib=2,
               gcs_gib=20, log_gib=8, log_retention=30),
    "prod": dict(sql=(2, 8), sql_ha=True, disk=50, backup_gib=50,
                 api_req_m=15, fe_req_m=5, events_m=3,
                 run_min={"frontend": (1, 1, 0.5), "api": (2, 1, 1), "worker": (1, 1, 1)},
                 api_mem=1, worker_mem=1,
                 cdn_gib=300, api_egress_gib=145, nat_avg_inst=5, nat_gib=10,
                 gcs_gib=100, log_gib=42, log_retention=90),
}

ALERT_CONDITIONS = 14   # 12 de servicios/BD/colas/jobs + 2 de uptime
ARMOR_RULES = 7         # 5 WAF (sqli, xss, lfi, rce, log4j) + rate limit + por defecto
LB_RULES = 2            # HTTPS + redirección HTTP


def env_items(e):
    c = ENV[e]
    it = []  # (servicio, concepto, fijo|variable, usd/mes)
    add = lambda svc, what, kind, usd: it.append((svc, what, kind, round(usd, 2)))

    # Cloud SQL
    if c["sql"] == "g1-small":
        add("Cloud SQL", "db-g1-small zonal", "fijo", P["sql_g1_small_h"] * H)
    else:
        vcpu, gib = c["sql"]; k = 2 if c["sql_ha"] else 1
        add("Cloud SQL", f"{vcpu} vCPU / {gib} GiB {'HA regional' if c['sql_ha'] else 'zonal'}", "fijo",
            k * (vcpu * P["sql_vcpu_h"] + gib * P["sql_gib_h"]) * H)
    add("Cloud SQL", f"SSD {c['disk']} GiB" + (" (×2 HA)" if c["sql_ha"] else ""), "variable",
        c["disk"] * P["sql_ssd"] * (2 if c["sql_ha"] else 1))
    add("Cloud SQL", f"backups ~{c['backup_gib']} GiB", "variable", c["backup_gib"] * P["sql_backup"])

    # Cloud Run: instancias mínimas (inactivas) + tiempo activo + peticiones
    idle = sum(n * (cpu + mem) * S * P["run_idle"] for n, cpu, mem in c["run_min"].values())
    if idle:
        add("Cloud Run", "instancias mínimas (frontend 1, api 2, worker 1)", "fijo", idle)
    active_s = c["api_req_m"] * 1e6 * 0.15 / 20 + c["events_m"] * 1e6 * 0.10 / 10 + c["fe_req_m"] * 1e6 * 0.02 / 50
    add("Cloud Run", "tiempo activo (150 ms/petición, concurrencia efectiva 20)", "variable",
        active_s * (P["run_cpu"] + c["api_mem"] * P["run_mem"]))
    add("Cloud Run", "peticiones", "variable", (c["api_req_m"] + c["fe_req_m"] + c["events_m"]) * P["run_req_m"])
    add("Cloud Run Jobs", "conciliación diaria 10 min + reportes semanal 30 min", "variable",
        30 * 600 * (P["job_cpu"] + P["job_mem"]) + 4.3 * 1800 * (P["job_cpu"] + 2 * P["job_mem"]))

    # Borde
    add("Load Balancer", f"{LB_RULES} reglas de reenvío", "fijo", LB_RULES and P["lb_rule_h"] * H)
    lb_gib = c["cdn_gib"] + c["api_egress_gib"] + c["api_req_m"] * 1e6 * 2e3 / 2**30
    add("Load Balancer", f"datos procesados ~{lb_gib:.0f} GiB", "variable", lb_gib * P["lb_gib"])
    add("Cloud CDN", f"salida ~{c['cdn_gib']} GiB + llenado + consultas", "variable",
        c["cdn_gib"] * P["cdn_gib"] + c["cdn_gib"] * 0.05 * P["cdn_fill"] + c["fe_req_m"] * 1e6 / 1e4 * P["cdn_lookup_10k"])
    add("Internet egress", f"respuestas de API ~{c['api_egress_gib']} GiB", "variable", c["api_egress_gib"] * P["egress_gib"])
    add("Cloud Armor", f"política + {ARMOR_RULES} reglas", "fijo", P["armor_policy"] + ARMOR_RULES * P["armor_rule"])
    add("Cloud Armor", "peticiones evaluadas", "variable", (c["api_req_m"] + c["fe_req_m"] * 0.2) * P["armor_req_m"])

    # Red
    add("Cloud NAT", "IP + pasarela (instancias medias conectadas)", "fijo",
        P["ip_h"] * H + c["nat_avg_inst"] * P["nat_vm_h"] * H)
    add("Cloud NAT", f"datos ~{c['nat_gib']} GiB", "variable", c["nat_gib"] * P["nat_gib"])

    # Datos y mensajería
    pubsub_gib = c["events_m"] * 1e6 * 2 * 2e3 / 2**30  # publicación + entrega, ~2 KB
    add("Pub/Sub", f"~{pubsub_gib:.0f} GiB de mensajes", "variable", pubsub_gib / 1024 * P["pubsub_tib"])
    add("Cloud Storage", f"{c['gcs_gib']} GiB Standard + operaciones", "variable",
        c["gcs_gib"] * P["gcs_std"] + c["api_req_m"] * 0.01 * 1e6 / 1e4 * P["gcs_a_10k"] + c["api_req_m"] * 0.05 * 1e6 / 1e4 * P["gcs_b_10k"])
    add("Secret Manager", "3 secretos activos", "fijo", 3 * P["secret_ver"])

    # Operación
    add("Cloud Logging", f"ingesta ~{c['log_gib']} GiB (50 GiB/proyecto gratis)", "variable",
        max(0, c["log_gib"] - P["log_free"]) * P["log_gib"])
    if c["log_retention"] > 30:
        add("Cloud Logging", f"retención {c['log_retention']} días", "variable",
            c["log_gib"] * (c["log_retention"] - 30) / 30 * P["log_ret"])
    add("Cloud Monitoring", f"{ALERT_CONDITIONS} condiciones de alerta", "fijo", ALERT_CONDITIONS * P["alert_cond"])
    add("Cloud Scheduler", "2 jobs programados", "fijo", 2 * P["scheduler_job"])
    return it


def shared_items():
    return [
        ("Artifact Registry", "~3 GiB de imágenes (0,5 GiB gratis)", "variable", round((3 - 0.5) * P["ar_gib"], 2)),
        ("Cloud Build", "~1.300 min/mes, dentro de los 2.500 gratis", "variable", 0.0),
        ("Cloud Storage", "estado de Terraform", "fijo", 0.01),
    ]


def logging_growth(e, year):
    """Logging solo cobra por encima de 50 GiB: se recalcula con el volumen del año."""
    c = ENV[e]; gib = c["log_gib"] * GROWTH[year]
    usd = max(0, gib - P["log_free"]) * P["log_gib"]
    if c["log_retention"] > 30:
        usd += gib * (c["log_retention"] - 30) / 30 * P["log_ret"]
    return usd


def main():
    out = Path(__file__).parent
    rows, totals = [], {}
    for e in ["dev", "qa", "prod", "shared"]:
        items = shared_items() if e == "shared" else env_items(e)
        for year in (1, 2, 3):
            g = GROWTH[year]
            month = 0.0
            for svc, what, kind, usd in items:
                if svc == "Cloud Logging" and e != "shared":
                    continue
                v = usd * (g if kind == "variable" else 1)
                month += v
                if year == 1:
                    rows.append([e, svc, what, kind, f"{usd:.2f}", f"{usd * (GROWTH[2] if kind == 'variable' else 1):.2f}",
                                 f"{usd * (GROWTH[3] if kind == 'variable' else 1):.2f}"])
            if e != "shared":
                lg = logging_growth(e, year)
                month += lg
                if year == 1:
                    rows.append([e, "Cloud Logging", "ingesta y retención", "variable",
                                 f"{logging_growth(e, 1):.2f}", f"{logging_growth(e, 2):.2f}", f"{logging_growth(e, 3):.2f}"])
            totals[(e, year)] = month

    with open(out / "presupuesto.csv", "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["ambiente", "servicio", "concepto", "tipo", "usd_mes_año1", "usd_mes_año2", "usd_mes_año3"])
        w.writerows(rows)

    fmt = lambda x: f"{x:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
    md = ["| Ambiente | Año 1 $/mes | Año 1 $/año | Año 2 $/mes | Año 2 $/año | Año 3 $/mes | Año 3 $/año |",
          "|---|--:|--:|--:|--:|--:|--:|"]
    grand = {1: 0, 2: 0, 3: 0}
    for e in ["dev", "qa", "prod", "shared"]:
        cells = []
        for y in (1, 2, 3):
            m = totals[(e, y)]; grand[y] += m
            cells += [fmt(m), fmt(m * 12)]
        md.append(f"| {e.upper() if e != 'shared' else 'Shared (CI/CD)'} | " + " | ".join(cells) + " |")
    md.append("| **Total** | " + " | ".join(f"**{fmt(grand[y])}**|**{fmt(grand[y] * 12)}**" for y in (1, 2, 3)) + " |")
    md.append("")
    md.append(f"**Total a 3 años: {fmt(sum(grand[y] * 12 for y in (1, 2, 3)))} USD** (precios de lista, sin impuestos ni descuentos).")
    md.append("")
    for e in ["dev", "qa", "prod"]:
        md += ["", f"#### {e.upper()} (año 1)", "", "| Servicio | Concepto | Tipo | $/mes |", "|---|---|---|--:|"]
        for r in rows:
            if r[0] == e:
                md.append(f"| {r[1]} | {r[2]} | {r[3]} | {fmt(float(r[4]))} |")
    (out / "tablas.md").write_text("\n".join(md) + "\n")
    print("\n".join(md[:8]))


if __name__ == "__main__":
    main()
