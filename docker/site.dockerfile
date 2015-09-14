FROM msaraiva/alpine-elixir-base:18.0

RUN apk --update add erlang-sasl bash && rm -rf /var/cache/apk/*
ENV SHELL=/bin/bash TERM=xterm

RUN adduser -h /erlangelist -s /bin/bash -D erlangelist
COPY tmp /erlangelist/
RUN chown -R erlangelist:erlangelist /erlangelist

# Default pass is blank, so generate a random root pass.
RUN \
  password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c${1:-32};echo;) \
  && printf "$password\n$password\n" | passwd root

USER erlangelist
