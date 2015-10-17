FROM msaraiva/alpine-erlang-base:3.2

RUN echo 'http://dl-4.alpinelinux.org/alpine/edge/community' >> /etc/apk/repositories

RUN apk --update add \
  elixir erlang-runtime-tools erlang-snmp erlang-crypto erlang-syntax-tools \
  erlang-inets erlang-ssl erlang-public-key erlang-eunit \
  erlang-asn1 erlang-sasl erlang-erl-interface erlang-dev \
  wget git curl nodejs \
  && rm -rf /var/cache/apk/*
RUN mix local.hex --force && mix local.rebar --force
RUN npm install -g brunch

COPY site/package.json /tmp/erlangelist/site/
RUN cd /tmp/erlangelist/site && npm install

COPY site/mix.exs /tmp/erlangelist/site/
COPY site/mix.lock /tmp/

# Very ugly hack that forces erlcron for R18
RUN cat /tmp/mix.lock \
      | sed s/ac499360fe263a5d24b4a47185691fa2e54c10f7/474ebd59dc834b2549ea46e176722e446bb8f7ef/ \
      > /tmp/erlangelist/site/mix.lock

RUN cd /tmp/erlangelist/site && mix deps.get && MIX_ENV=prod mix deps.compile && MIX_ENV=test mix deps.compile

COPY site /tmp/erlangelist/site

# Have to do it again, since we copied the site again
RUN cat /tmp/mix.lock \
      | sed s/ac499360fe263a5d24b4a47185691fa2e54c10f7/474ebd59dc834b2549ea46e176722e446bb8f7ef/ \
      > /tmp/erlangelist/site/mix.lock

RUN cd /tmp/erlangelist/site \
    && MIX_ENV=prod mix compile \
    && brunch build --production \
    && MIX_ENV=prod mix phoenix.digest \
    && MIX_ENV=prod mix release
