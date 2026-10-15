// Punto de entrada de las migraciones (job <app>-<env>-migrate, antes de cada despliegue).
// Esquema mínimo idempotente. En el proyecto real iría una herramienta (node-pg-migrate, Prisma,
// Flyway…). Entra como app_admin: DB_INSTANCE_CONNECTION, DB_NAME, DB_USER y DB_PASSWORD llegan
// como variables y secreto desde Terraform.
import { log } from "./log.js";
import { getPool } from "./db.js";

const required = ["DB_INSTANCE_CONNECTION", "DB_NAME", "DB_USER", "DB_PASSWORD"];
const missing = required.filter((k) => !process.env[k]);
if (missing.length) {
  log("ERROR", "faltan variables para migrar", { missing });
  process.exit(1);
}

const steps = [
  `create table if not exists pedidos (
     id     text primary key,
     creado timestamptz not null default now(),
     datos  jsonb not null default '{}'
   )`,
  // Las service accounts de la app (usuarios IAM) heredan de este rol de Cloud SQL.
  "grant select, insert on pedidos to cloudsqliamserviceaccount",
];

try {
  const pool = await getPool();
  for (const sql of steps) await pool.query(sql);
  await pool.end();
  log("INFO", "migraciones aplicadas", { pasos: steps.length });
  process.exit(0);
} catch (err) {
  log("ERROR", "fallo en la migración", { error: String(err) });
  process.exit(1);
}
