# router-fw : routeur inter-zones + pare-feu nftables
FROM alpine:3.20

RUN apk add --no-cache nftables iproute2 iputils curl bind-tools tcpdump

COPY nftables.conf /etc/nftables.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

HEALTHCHECK --interval=30s --timeout=5s CMD nft list table inet filter >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
