// Recibe los push de Pub/Sub (con token OIDC validado por Cloud Run: ingress interno + invoker).
// 2xx = ack; cualquier otro código hace que Pub/Sub reintente con backoff y, agotados los
// intentos, mande el mensaje a la DLQ. Los handlers deben ser idempotentes (entrega al menos una vez).
import http from "node:http";
import { log } from "./log.js";
import { getPool } from "./db.js";

const port = Number(process.env.PORT ?? 8080);

const handlers = {
  // Idempotente: el id del pedido es la clave, una reentrega no duplica la fila.
  "/events/pedidos": async (data) => {
    if (!data.id) throw new Error("pedido sin id");
    const pool = await getPool();
    const r = await pool.query("insert into pedidos (id, datos) values ($1, $2) on conflict (id) do nothing", [data.id, data]);
    log("INFO", "pedido guardado", { id: data.id, nuevo: r.rowCount === 1 });
  },
  "/events/entregas": async (data) => log("INFO", "entrega recibida", { id: data.id }),
  "/events/integraciones": async (data) => log("INFO", "integración recibida", { origen: data.origen }),
};

const readBody = (req) =>
  new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (c) => (body += c));
    req.on("end", () => resolve(body));
    req.on("error", reject);
  });

const server = http.createServer(async (req, res) => {
  const path = new URL(req.url, "http://localhost").pathname;
  if (path === "/healthz") return res.writeHead(200).end("ok");
  const handler = handlers[path];
  if (req.method !== "POST" || !handler) return res.writeHead(404).end();
  try {
    const { message } = JSON.parse(await readBody(req));
    const data = JSON.parse(Buffer.from(message.data ?? "", "base64").toString() || "{}");
    await handler(data, message.attributes ?? {});
    res.writeHead(204).end();
  } catch (err) {
    log("ERROR", "fallo procesando evento", { path, error: String(err) });
    res.writeHead(500).end();
  }
});

server.listen(port, () => log("INFO", `worker escuchando en ${port}`));
process.on("SIGTERM", () => server.close(() => process.exit(0)));
