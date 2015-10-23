# Defines the ports used used in the system. The settings here will be propagated
# to other services, and ultimately used in production.
defmodule Erlangelist.SystemSettings do
  base_port = String.to_integer(System.get_env("ERLANGELIST_BASE_PORT") || "20000")

  port_offsets = [
    site_http: 0,
    admin_http: 1,
    postgres: 2,
    graphite_nginx: 3,
    carbon: 4,
    statsd: 5,
    geo_ip: 6,
    site_inet_dist: 7
  ]

  system_settings =
    for {type, offset} <- port_offsets do
      {:"#{type}_port", base_port + offset}
    end

  system_settings =
    if Mix.env == :prod do
      {additional_settings, _bindings} = Code.eval_file(
        "#{Path.dirname(__ENV__.file)}/prod_settings.exs"
      )
      Keyword.merge(system_settings, additional_settings)
    else
      system_settings
    end

  for {name, value} <- system_settings do
    def value(unquote(name)), do: unquote(value)
  end
  def value(_), do: nil

  def env_vars do
    unquote(
      for {name, value} <- system_settings do
        "export #{String.upcase("ERLANGELIST_#{name}")}=#{to_string(value)}\n"
      end
    )
  end
end