# dns-lan : serveur DNS interne du LAN (dnsmasq)
FROM alpine:3.20

RUN apk upgrade --no-cache && apk add --no-cache dnsmasq iproute2 bind-tools

COPY dnsmasq.conf /etc/dnsmasq.conf

# Valeurs par défaut, surchargées par Ansible selon l'environnement
ENV GATEWAY=172.20.2.1 \
    DNSMASQ_CONF=/etc/dnsmasq.conf

EXPOSE 53/udp 53/tcp

HEALTHCHECK --interval=30s --timeout=5s CMD dig +short @127.0.0.1 fw.pme.local | grep -q . || exit 1

# Route par défaut via le pare-feu, puis dnsmasq au premier plan
CMD ["sh", "-c", "ip route replace default via $GATEWAY && exec dnsmasq --keep-in-foreground --log-facility=- -C $DNSMASQ_CONF"]
