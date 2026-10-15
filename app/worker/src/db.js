// Conexión a Cloud SQL por IP privada con el Cloud SQL Node.js Connector (TLS y autorización IAM,
// sin IPs autorizadas ni proxy). Las apps entran con su service account (authType IAM, sin
// contraseña); la migración entra como app_admin con la contraseña de Secret Manager.
import { Connector, IpAddressTypes, AuthTypes } from "@google-cloud/cloud-sql-connector";
import pg from "pg";

let pool;

export const getPool = async () => {
  if (pool) return pool;
  const connector = new Connector();
  const password = process.env.DB_PASSWORD;
  const opts = await connector.getOptions({
    instanceConnectionName: process.env.DB_INSTANCE_CONNECTION,
    ipType: process.env.DB_IP_TYPE === "PUBLIC" ? IpAddressTypes.PUBLIC : IpAddressTypes.PRIVATE,
    ...(password ? {} : { authType: AuthTypes.IAM }),
  });
  pool = new pg.Pool({
    ...opts,
    user: process.env.DB_USER,
    password,
    database: process.env.DB_NAME,
    max: Number(process.env.DB_POOL_MAX ?? 8),
  });
  return pool;
};
