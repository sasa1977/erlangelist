FROM msaraiva/alpine-elixir-base:18.0

RUN apk --update add erlang-sasl bash && rm -rf /var/cache/apk/*
ENV SHELL=/bin/bash TERM=xterm
RUN mkdir -p /erlangelist
COPY tmp /erlangelist/
