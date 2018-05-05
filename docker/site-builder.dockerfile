FROM bitwalker/alpine-elixir-phoenix:latest

ENV MIX_ENV=prod

ADD site/mix.exs site/mix.lock ./
RUN mix do deps.get, deps.compile

ADD site/assets/package.json assets/
RUN cd assets && npm install

ADD site .
RUN mix release
