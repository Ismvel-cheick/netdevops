# dns-lan : serveur DNS interne du LAN (dnsmasq)
FROM alpine:3.20

RUN apk add --no-cache dnsmasq iproute2 bind-tools

COPY dnsmasq.conf /etc/dnsmasq.conf

EXPOSE 53/udp 53/tcp

HEALTHCHECK --interval=30s --timeout=5s CMD dig +short @127.0.0.1 www.pme.local | grep -q 172.20.1.10 || exit 1

# Route par défaut via le pare-feu (172.20.2.1), puis dnsmasq au premier plan
CMD ["sh", "-c", "ip route replace default via 172.20.2.1 && exec dnsmasq --keep-in-foreground --log-facility=-"]
