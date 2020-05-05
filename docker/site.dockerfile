FROM alpine:3.11

RUN \
  echo 'http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
  echo 'http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
  apk --no-cache upgrade && apk add --no-cache openssl bash certbot

COPY tmp /erlangelist/

VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/db
VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/backup
WORKDIR /erlangelist
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
