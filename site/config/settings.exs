defmodule Erlangelist.Settings do
  def all do
    peer_ip = case Mix.env do
      :prod -> "172.17.42.1"
      _ -> "127.0.0.1"
    end

    secret_key_base = system_setting(:secret_key_base) || String.duplicate("1", 64)

    exometer_polling_interval = for_env(
      common: :timer.seconds(5),
      dev: :timer.seconds(1)
    )

    [
      kernel: [
        inet_dist_listen_min: system_setting(:site_inet_dist_port),
        inet_dist_listen_max: system_setting(:site_inet_dist_port)
      ],

      sasl: [
        sasl_error_logger: false
      ],

      lager: [
        error_logger_redirect: false,
        error_logger_whitelist: [Logger.ErrorHandler],
        crash_log: false,
        handlers: [{LagerLogger, [level: :info]}]
      ],

      logger: [
        console: [
          format: for_env(
            prod: "$time $metadata[$level] $message\n",
            dev: "[$level] $message\n"
          ),
          metadata: for_env(prod: [:request_id])
        ],

        sync_threshold: 1000,

        level: for_env(dev: :debug, test: :warn, prod: :info)
      ],

      phoenix: [
        stacktrace_depth: for_env(dev: 20, test: 20),
        serve_endpoints: for_env(prod: true)
      ],

      erlcron: [
        crontab: for_env(prod: [])
      ],

      exometer: [
        predefined: [
          {
            ~w(erlang memory)a,
            {:function, :erlang, :memory, [], :proplist, ~w(atom binary ets processes total)a},
            []
          },
          {
            ~w(erlang statistics)a,
            {:function, :erlang, :statistics, [:'$dp'], :value, [:run_queue]},
            []
          }
        ],

        reporters: [
          exometer_report_statsd: [
            hostname: '#{peer_ip}',
            port: system_setting(:statsd_port)
          ],
        ],

        report: [
          subscribers: [
            {
              :exometer_report_statsd,
              [:erlang, :memory],
              ~w(atom binary ets processes total)a,
              exometer_polling_interval
            }
          ]
        ]
      ],

      erlangelist: [
        {Erlangelist.Endpoint.Site,
          url: for_env(
            common: [host: "localhost"],
            prod: [host: "theerlangelist.com", port: 80]
          ),

          http: [
            port: for_env(
              common: system_setting(:site_http_port),
              test: 4001
            ),
            max_connections: 1000,
            compress: true
          ],

          root: Path.dirname(__DIR__),
          secret_key_base: secret_key_base,
          render_errors: [accepts: ~w(html json)],
          pubsub: [name: Erlangelist.PubSub.Site, adapter: Phoenix.PubSub.PG2],

          debug_errors: for_env(dev: true),
          code_reloader: for_env(dev: true),
          cache_static_lookup: for_env(dev: false),
          check_origin: for_env(dev: false),
          watchers: for_env(dev: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]]),
          live_reload: for_env(dev: [
            patterns: [
              ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
              ~r{web/views/.*(ex)$},
              ~r{web/templates/.*(eex)$},
              ~r{articles/.*$}
            ]
          ]),

          server: for_env(test: false),
          cache_static_manifest: for_env(prod: "priv/static/manifest.json")
        },

        {Erlangelist.Repo,
          adapter: Ecto.Adapters.Postgres,
          hostname: System.get_env("ERLANGELIST_DB_SERVER") || peer_ip,
          port: for_env(common: 5432, prod: system_setting(:postgres_port)),
          database: System.get_env("ERLANGELIST_DB") || for_env(common: "erlangelist", test: "erlangelist_test"),
          username: "erlangelist",
          password: system_setting(:db_password) || ""
        },

        peer_ip: peer_ip,
        geo_ip: system_setting(:geo_ip_port),

        exometer_polling_interval: exometer_polling_interval,

        articles_cache: for_env(
          # keeps items forever
          common: [],
          # quick expiration in dev
          dev: [
            ttl_check: :timer.seconds(1),
            ttl: :timer.seconds(1)
          ]
        ),

        rate_limiters: [
          {:per_second, :timer.seconds(1)},
          {:per_minute, :timer.minutes(1)}
        ],
        rate_limited_operations: [
          plug_logger: for_env(prod: {:per_second, 100}),
          request_db_log: for_env(prod: {:per_minute, 600}),
          limit_warn_log: {:per_minute, for_env(prod: 1, common: 0)},
          geoip_query: {:per_second, for_env(prod: 50, common: 0)}
        ]
      ]
    ]
    |> remove_undefined
  end

  defp for_env(choices) do
    case Keyword.fetch(choices, Mix.env) do
      {:ok, value} -> value
      :error ->
        case Keyword.fetch(choices, :common) do
          {:ok, value} -> value
          :error -> undefined
        end
    end
  end

  @undefined {__MODULE__, :undefined}
  defp undefined, do: @undefined

  defp remove_undefined([]), do: []
  defp remove_undefined([{_name, @undefined} | rest]), do: remove_undefined(rest)
  defp remove_undefined([head | rest]), do: [remove_undefined(head) | remove_undefined(rest)]
  defp remove_undefined(%{} = map) do
    map
    |> Map.to_list
    |> remove_undefined
    |> Enum.into(%{})
  end
  defp remove_undefined(tuple) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list
    |> remove_undefined
    |> List.to_tuple
  end
  defp remove_undefined(term), do: term


  # System settings (valid for multiple containers)
  base_port = String.to_integer(System.get_env("ERLANGELIST_BASE_PORT") || "20000")

  port_offsets = [
    site_http: 0,
    # offset 1 was used for the admin site which no longer exists
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
    def system_setting(unquote(name)), do: unquote(value)
  end
  def system_setting(_), do: nil

  def env_vars do
    unquote(
      for {name, value} <- system_settings do
        "export #{String.upcase("ERLANGELIST_#{name}")}=#{to_string(value)}\n"
      end
    )
  end
end
