FROM elixir:1.10.3-alpine as builder

RUN apk add --no-cache \
      git \
      make \
      g++ \
      wget \
      curl \
      inotify-tools \
      nodejs \
      nodejs-npm && \
    mix local.hex --force && \
    mix local.rebar --force && \
    npm install npm -g --no-progress && \
    update-ca-certificates --fresh && \
    rm -rf /var/cache/apk/*

ENV MIX_ENV=prod

WORKDIR /opt/app

ADD site/mix.exs site/mix.lock ./site/
RUN cd site && mix do deps.get, deps.compile

ADD site/assets/package.json site/assets/
RUN cd site/assets && (npm install || (sleep 1 && npm install) || (sleep 1 && npm install))

ADD site ./site
RUN cd site && mix release


FROM alpine:3.11 as site

RUN \
  echo 'http://nl.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories && \
  echo 'http://nl.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories && \
  apk --no-cache upgrade && apk add --no-cache openssl bash certbot

COPY --from=builder /opt/app/site/_build/prod/rel/erlangelist /erlangelist

VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/db
VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/backup
WORKDIR /erlangelist
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
