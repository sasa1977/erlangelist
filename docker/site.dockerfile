FROM debian:jessie

RUN apt-get update && apt-get install -y openssl
RUN useradd -d /erlangelist -s /bin/bash erlangelist
COPY tmp /erlangelist/
RUN chown -R erlangelist:erlangelist /erlangelist

# Default pass is blank, so generate a random root pass.
RUN \
  password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;) \
  && printf "$password\n$password\n" | passwd root

USER erlangelist

ENTRYPOINT ["/erlangelist/bin/erlangelist"]
