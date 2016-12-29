FROM elixir:1.3.4

RUN mix local.hex --force && mix local.rebar --force
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash -
RUN apt-get install -y nodejs

# fetch & compile deps
COPY site/mix.exs site/mix.lock site/package.json /tmp/erlangelist/site/
RUN cd /tmp/erlangelist/site \
    && mix deps.get \
    && MIX_ENV=prod mix deps.compile \
    && MIX_ENV=test mix deps.compile \
    && npm install -g brunch \
    && npm install

# copy the entire site & build the release
COPY site /tmp/erlangelist/site
RUN cd /tmp/erlangelist/site \
    && MIX_ENV=prod mix compile \
    && brunch build --production \
    && MIX_ENV=prod mix phoenix.digest \
    && MIX_ENV=prod mix release
