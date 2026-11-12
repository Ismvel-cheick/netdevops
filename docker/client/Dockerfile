# client : poste du LAN servant aux tests de connectivité
FROM alpine:3.20

RUN apk add --no-cache curl bind-tools nmap nmap-scripts iproute2 iputils

# Route par défaut via le pare-feu (172.20.2.1)
CMD ["sh", "-c", "ip route replace default via 172.20.2.1 && exec tail -f /dev/null"]
