# Estáticos servidos por nginx sin root en 8080. Con un framework (React/Vue…), añadir una
# etapa de build con node y copiar aquí solo el resultado.
FROM nginxinc/nginx-unprivileged:1.30-alpine3.24
COPY security-headers.conf /etc/nginx/snippets/security-headers.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public /usr/share/nginx/html
EXPOSE 8080
