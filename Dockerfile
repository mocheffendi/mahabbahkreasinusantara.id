# ---- Build: static site (ngnix) ----
FROM nginx:1.27-alpine

# Konfigurasi Nginx (gzip, cache, fallback SPA)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Salin seluruh landing page
COPY public/ /usr/share/nginx/html/

EXPOSE 80

# Healthcheck sederhana
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
