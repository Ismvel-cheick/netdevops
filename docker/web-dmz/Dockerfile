# web-dmz : serveur Nginx exposé (HTTP -> HTTPS)
FROM nginx:1.27-alpine

RUN apk add --no-cache openssl iproute2 \
 && mkdir -p /etc/nginx/ssl \
 && openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
      -keyout /etc/nginx/ssl/server.key -out /etc/nginx/ssl/server.crt \
      -subj "/C=CI/O=PME/CN=www.pme.local" \
 && chmod 600 /etc/nginx/ssl/server.key

COPY default.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html

HEALTHCHECK --interval=30s --timeout=5s CMD wget -qO- http://127.0.0.1:8080/nginx_status >/dev/null || exit 1

# La route par défaut passe par le pare-feu (172.20.1.1), puis Nginx démarre
CMD ["sh", "-c", "ip route replace default via 172.20.1.1 && exec nginx -g 'daemon off;'"]
