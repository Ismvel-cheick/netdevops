# router-fw : routeur inter-zones + pare-feu nftables
FROM alpine:3.20

# prometheus-node-exporter : expose les compteurs réseau du routeur (trafic par zone)
RUN apk upgrade --no-cache && apk add --no-cache nftables iproute2 iputils curl bind-tools tcpdump prometheus-node-exporter

COPY nftables.conf /etc/nftables.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s CMD nft list table inet filter >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
