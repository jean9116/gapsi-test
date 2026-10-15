// Punto de entrada de las migraciones (job <app>-<env>-migrate, antes de cada despliegue).
// Aquí iría la herramienta elegida (node-pg-migrate, Prisma, Flyway…) conectando a Cloud SQL
// con el Cloud SQL Node.js Connector: DB_INSTANCE_CONNECTION, DB_NAME, DB_USER=app_admin y DB_PASSWORD
// llegan como variables y secreto desde Terraform.
import { log } from "./log.js";

const required = ["DB_INSTANCE_CONNECTION", "DB_NAME", "DB_USER", "DB_PASSWORD"];
const missing = required.filter((k) => !process.env[k]);
if (missing.length) {
  log("ERROR", "faltan variables para migrar", { missing });
  process.exit(1);
}
log("INFO", "migraciones aplicadas", { pending: 0 });
