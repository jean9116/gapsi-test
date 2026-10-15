import http from "node:http";
import { log } from "./log.js";

const port = Number(process.env.PORT ?? 8080);

const routes = {
  "GET /api/healthz": () => ({ status: "ok" }),
  "GET /api/version": () => ({ env: process.env.APP_ENV, revision: process.env.K_REVISION }),
};

const server = http.createServer((req, res) => {
  const path = new URL(req.url, "http://localhost").pathname;
  const handler = routes[`${req.method} ${path}`];
  const status = handler ? 200 : 404;
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(handler ? handler() : { error: "not found" }));
  if (path !== "/api/healthz") log("INFO", "request", { method: req.method, path, status });
});

server.listen(port, () => log("INFO", `api escuchando en ${port}`));

// Cloud Run envía SIGTERM y da 10 s antes de matar la instancia.
process.on("SIGTERM", () => server.close(() => process.exit(0)));
