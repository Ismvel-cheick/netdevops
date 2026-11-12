# client : poste du LAN servant aux tests de connectivité
FROM alpine:3.20

RUN apk add --no-cache curl bind-tools nmap nmap-scripts iproute2 iputils

# Passerelle = pare-feu (surchargée par Ansible selon l'environnement)
ENV GATEWAY=172.20.2.1

CMD ["sh", "-c", "ip route replace default via $GATEWAY && exec tail -f /dev/null"]
