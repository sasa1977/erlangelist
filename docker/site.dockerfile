FROM alpine:3.7

RUN apk --no-cache upgrade && apk add --no-cache openssl bash

COPY tmp /erlangelist/

VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/db
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
