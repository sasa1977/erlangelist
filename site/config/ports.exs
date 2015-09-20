# Defines the ports used used in the system. The settings here will be propagated
# to other services, and ultimately used in production.
defmodule Erlangelist.Ports do
  base_port = String.to_integer(System.get_env("ERLANGELIST_BASE_PORT") || "20000")

  offsets = [
    site_http: 0,
    admin_http: 1,
    postgres: 2,
    graphite_nginx: 3,
    carbon: 4,
    statsd: 5,
    geo_ip: 6,
    site_inet_dist: 7
  ]

  for {type, offset} <- offsets do
    def port(unquote(type)), do: unquote(base_port + offset)
  end

  def all do
    unquote(Enum.map(offsets, fn({type, offset}) -> {type, base_port + offset} end))
  end
end