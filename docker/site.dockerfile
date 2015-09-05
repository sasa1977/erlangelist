FROM msaraiva/alpine-elixir-base:18.0

RUN apk --update add erlang-sasl && rm -rf /var/cache/apk/*

RUN mkdir -p /erlangelist
COPY tmp /erlangelist/
