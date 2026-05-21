# ============================================================
# Tecnoglass Frontend — Angular 17 + Nginx
# Etapa 1: build con Node 18
# Etapa 2: serve con Nginx Alpine
# ============================================================

# ── Etapa 1: Build ──────────────────────────────────────────
FROM node:18-alpine AS build

WORKDIR /app

COPY package*.json ./
RUN npm install --legacy-peer-deps

COPY . .

# Build de producción (usa environment.prod.ts → apiUrl: '/api')
RUN npm run build

# ── Etapa 2: Nginx ───────────────────────────────────────────
FROM nginx:alpine

# Copiar archivos compilados (Angular 17 application builder → /browser/)
COPY --from=build /app/dist/tecnoglass-frontend/browser /usr/share/nginx/html

# Template de Nginx — envsubst reemplaza ${BACKEND_HOST} al arrancar el contenedor
# Solo sustituye BACKEND_HOST; las variables propias de nginx ($uri, $host, etc.) quedan intactas
COPY nginx.conf.template /etc/nginx/templates/default.conf.template

EXPOSE 80
