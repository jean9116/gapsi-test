// Cloud Run Job programado por Cloud Scheduler. Con task_count > 1, cada tarea procesa su
// parte: CLOUD_RUN_TASK_INDEX de CLOUD_RUN_TASK_COUNT. Salir con código != 0 marca la tarea
// como fallida y Cloud Run la reintenta (max_retries); la alerta "job fallido" avisa.
import { log } from "./log.js";

const task = Number(process.env.CLOUD_RUN_TASK_INDEX ?? 0);
const tasks = Number(process.env.CLOUD_RUN_TASK_COUNT ?? 1);

log("INFO", "conciliacion: inicio", { task, tasks });
// … lógica del proceso …
log("INFO", "conciliacion: fin", { task, procesados: 0 });
