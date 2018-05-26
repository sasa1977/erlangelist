FROM bitwalker/alpine-elixir-phoenix:latest

ENV MIX_ENV=prod

ADD site/mix.exs site/mix.lock ./site/
RUN cd site && mix do deps.get, deps.compile

ADD site/assets/package.json site/assets/
RUN cd site/assets && (npm install || (sleep 1 && npm install) || (sleep 1 && npm install))

ADD site ./site
RUN cd site && mix release
