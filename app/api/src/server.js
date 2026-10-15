import http from "node:http";
import { randomUUID } from "node:crypto";
import { log } from "./log.js";
import { getPool } from "./db.js";
import { publish } from "./pubsub.js";

const port = Number(process.env.PORT ?? 8080);

const readJson = (req) =>
  new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (err) {
        reject(err);
      }
    });
    req.on("error", reject);
  });

const routes = {
  "GET /api/healthz": async () => [200, { status: "ok" }],
  "GET /api/version": async () => [200, { env: process.env.APP_ENV, revision: process.env.K_REVISION }],
  // Comprueba la BD (IP privada + usuario IAM) y devuelve los últimos pedidos que guardó el worker.
  "GET /api/db": async () => {
    const pool = await getPool();
    const { rows: [info] } = await pool.query("select split_part(current_user, '@', 1) as usuario, version() as version, now() as ahora");
    const { rows: [{ total }] } = await pool.query("select count(*)::int as total from pedidos");
    const { rows: ultimos } = await pool.query("select id, creado, datos from pedidos order by creado desc limit 5");
    return [200, { ...info, pedidos: total, ultimos }];
  },
  // Publica el pedido en Pub/Sub; el worker lo procesa de forma asíncrona y lo guarda en la BD.
  "POST /api/pedidos": async (req) => {
    const pedido = { id: randomUUID(), ...(await readJson(req)) };
    const messageId = await publish(process.env.TOPIC_PEDIDOS, pedido);
    log("INFO", "pedido publicado", { id: pedido.id, messageId });
    return [202, { id: pedido.id, messageId }];
  },
};

const server = http.createServer(async (req, res) => {
  const path = new URL(req.url, "http://localhost").pathname;
  const handler = routes[`${req.method} ${path}`];
  let status = 404;
  let body = { error: "not found" };
  if (handler) {
    try {
      [status, body] = await handler(req);
    } catch (err) {
      log("ERROR", "fallo en la petición", { path, error: String(err), stack: err.stack });
      [status, body] = [500, { error: "error interno" }];
    }
  }
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(body));
  if (path !== "/api/healthz") log("INFO", "request", { method: req.method, path, status });
});

server.listen(port, () => log("INFO", `api escuchando en ${port}`));

// Cloud Run envía SIGTERM y da 10 s antes de matar la instancia.
process.on("SIGTERM", () => server.close(() => process.exit(0)));
