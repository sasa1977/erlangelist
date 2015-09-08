FROM msaraiva/elixir-dev:1.0.5

RUN apk --update add \
  erlang-runtime-tools erlang-snmp curl nodejs \
  && rm -rf /var/cache/apk/*
RUN npm install -g brunch

COPY site/package.json /tmp/erlangelist/site/
RUN cd /tmp/erlangelist/site && npm install

COPY site/mix.exs /tmp/erlangelist/site/
COPY site/mix.lock /tmp/erlangelist/site/

RUN cd /tmp/erlangelist/site && mix deps.get && MIX_ENV=prod mix deps.compile

COPY site /tmp/erlangelist/site

RUN cd /tmp/erlangelist/site \
    && MIX_ENV=prod mix compile \
    && brunch build --production \
    && MIX_ENV=prod mix phoenix.digest \
    && MIX_ENV=prod mix release
