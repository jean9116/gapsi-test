# Sin dependencias de npm todavía. Cuando las haya: COPY package-lock.json + npm ci --omit=dev.
FROM node:24-alpine3.24
ENV NODE_ENV=production
WORKDIR /app
COPY package.json ./
COPY src ./src
USER node
EXPOSE 8080
CMD ["node", "src/server.js"]
