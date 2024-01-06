FROM docker.io/library/alpine:3.19

RUN <<EOM
    apk add --no-cache bind bind-tools gettext
    chown named:named /etc/bind /var/bind
EOM

COPY --chown=named:named --chmod=0755 entrypoint.sh /
COPY --chown=named:named --chmod=0644 templates /templates

EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 8053/tcp

USER named

ENTRYPOINT ["/entrypoint.sh"]
