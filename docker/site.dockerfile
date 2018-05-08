FROM alpine:3.7

RUN apk --no-cache upgrade && apk add --no-cache openssl bash certbot

COPY tmp /erlangelist/

VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/db
VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/certbot
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
