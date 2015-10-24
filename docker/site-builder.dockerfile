FROM alpine:3.2

# install OS packages
RUN echo 'http://dl-4.alpinelinux.org/alpine/edge/main' >> /etc/apk/repositories \
    && echo 'http://dl-4.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories \
    && apk --update add \
        ncurses-libs=6.0-r0 \
        elixir=1.1.1-r0 erlang-runtime-tools erlang-snmp erlang-crypto erlang-syntax-tools \
        erlang-inets erlang-ssl erlang-public-key erlang-eunit \
        erlang-asn1 erlang-sasl erlang-erl-interface erlang-dev \
        wget git curl nodejs \
    && rm -rf /var/cache/apk/*
RUN mix local.hex --force && mix local.rebar --force

# install npm packages
RUN npm install -g brunch
COPY site/package.json /tmp/erlangelist/site/
RUN cd /tmp/erlangelist/site && npm install

# fetch & compile deps
COPY site/mix.exs site/mix.lock /tmp/erlangelist/site/
RUN cd /tmp/erlangelist/site && mix deps.get && MIX_ENV=prod mix deps.compile && MIX_ENV=test mix deps.compile

# copy the entire site & build the release
COPY site /tmp/erlangelist/site
RUN cd /tmp/erlangelist/site \
    && MIX_ENV=prod mix compile \
    && brunch build --production \
    && MIX_ENV=prod mix phoenix.digest \
    && MIX_ENV=prod mix release
