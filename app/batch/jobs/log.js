// Logs JSON en una línea: Cloud Logging los indexa por severity y campos.
export const log = (severity, message, extra = {}) =>
  console.log(JSON.stringify({ severity, message, ...extra }));
