FROM trenpixster/elixir:1.0.5

RUN curl -sL https://deb.nodesource.com/setup_0.12 | sudo bash - \
    && apt-get -y install nodejs inotify-tools

# RUN mix local.hex --force \
#     && mix archive.install https://github.com/phoenixframework/phoenix/releases/download/v1.0.0/phoenix_new-1.0.0.ez --force

COPY . /tmp/erlangelist

RUN cd /tmp/erlangelist/site \
    && npm install \
    && npm install -g brunch \
    && mix deps.get \
    && MIX_ENV=prod mix compile \
    && brunch build --production \
    && MIX_ENV=prod mix phoenix.digest \
    && MIX_ENV=prod mix release
