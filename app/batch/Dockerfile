# Sin dependencias de npm todavía. Cuando las haya: COPY package-lock.json + npm ci --omit=dev.
FROM node:24-alpine3.24
ENV NODE_ENV=production
WORKDIR /app
COPY package.json ./
COPY jobs ./jobs
USER node
# El comando lo fija cada job (args en Terraform), p. ej. node jobs/conciliacion.js
CMD ["node", "jobs/conciliacion.js"]
