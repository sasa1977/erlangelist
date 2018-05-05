FROM alpine:3.7

RUN apk --no-cache upgrade && apk add --no-cache openssl bash

RUN adduser -h /erlangelist -s /bin/bash -D erlangelist
COPY tmp /erlangelist/
RUN chown -R erlangelist:erlangelist /erlangelist

# Default pass is blank, so generate a random root pass.
RUN \
  password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;) \
  && printf "$password\n$password\n" | passwd root

USER erlangelist
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
