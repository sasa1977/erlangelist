defmodule Erlangelist.Settings do
  peer_ip = case Mix.env do
    :prod -> "172.17.42.1"
    _ -> "127.0.0.1"
  end

  secret_key_base = Erlangelist.SystemSettings.value(:secret_key_base) || String.duplicate("1", 64)

  apps_settings = [
    kernel: [
      inet_dist_listen_min: [common: Erlangelist.SystemSettings.value(:site_inet_dist_port)],
      inet_dist_listen_max: [common: Erlangelist.SystemSettings.value(:site_inet_dist_port)]
    ],

    sasl: [
      sasl_error_logger: [common: false]
    ],

    lager: [
      error_logger_redirect: [common: false],
      error_logger_whitelist: [common: [Logger.ErrorHandler]],
      crash_log: [common: false],
      handlers: [common: [{LagerLogger, [level: :info]}]]
    ],

    logger: [
      console: [
        common: [
          format: "$time $metadata[$level] $message\n",
          metadata: [:request_id]
        ],
        dev: [
          format: "[$level] $message\n"
        ]
      ],

      sync_threshold: [
        common: 1000
      ],

      level: [
        dev: :debug,
        test: :warn,
        prod: :info
      ]
    ],

    phoenix: [
      stacktrace_depth: [
        dev: 20,
        test: 20
      ],
      serve_endpoints: [
        prod: true
      ]
    ],

    erlcron: [
      crontab: [
        test: [],
        common: [
          {
            {:daily, {5, 0, :am}},
            {Erlangelist.Analytics, :compact, []}
          }
        ]
      ]
    ],

    erlangelist: [
      # Main site
      {Erlangelist.Endpoint.Site,
        common: [
          url: [host: "localhost"],
          http: [port: Erlangelist.SystemSettings.value(:site_http_port), max_connections: 1000],
          root: Path.dirname(__DIR__),
          secret_key_base: secret_key_base,
          render_errors: [accepts: ~w(html json)],
          pubsub: [name: Erlangelist.PubSub.Site, adapter: Phoenix.PubSub.PG2],
          http: [compress: true]
        ],

        dev: [
          debug_errors: true,
          code_reloader: true,
          cache_static_lookup: false,
          check_origin: false,
          watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]],
          live_reload: [
            patterns: [
              ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
              ~r{web/views/.*(ex)$},
              ~r{web/templates/.*(eex)$},
              ~r{articles/.*$}
            ]
          ]
        ],

        test: [http: [port: 4001], server: false],

        prod: [
          url: [host: "theerlangelist.com", port: 80],
          cache_static_manifest: "priv/static/manifest.json"
        ]
      },

      # Admin site
      {Erlangelist.Endpoint.Admin,
        common: [
          url: [host: "localhost"],
          http: [port: Erlangelist.SystemSettings.value(:admin_http_port)],
          root: Path.dirname(__DIR__),
          secret_key_base: secret_key_base,
          render_errors: [accepts: ~w(html json)],
          pubsub: [name: Erlangelist.PubSub.Admin, adapter: Phoenix.PubSub.PG2],
          http: [compress: true]
        ],

        dev: [
          debug_errors: true,
          code_reloader: true,
          cache_static_lookup: false,
          check_origin: false,
          watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]],
          live_reload: [
            patterns: [
              ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
              ~r{web/views/.*(ex)$},
              ~r{web/templates/.*(eex)$},
              ~r{articles/.*$}
            ]
          ]
        ],

        test: [http: [port: 4002], server: false]
      },

      {Erlangelist.Repo,
        common: [
          adapter: Ecto.Adapters.Postgres,
          database: "erlangelist",
          username: "erlangelist",
          password: Erlangelist.SystemSettings.value(:db_password) || "",
          hostname: peer_ip,
          port: 5432
        ],

        test: [
          hostname: System.get_env("ERLANGELIST_SERVER") || peer_ip,
          database: System.get_env("ERLANGELIST_DB") || "erlangelist_test"
        ],

        prod: [port: Erlangelist.SystemSettings.value(:postgres_port)]
      },

      peer_ip: [common: peer_ip],
      geo_ip: [common: Erlangelist.SystemSettings.value(:geo_ip_port)],

      exometer_polling_interval: [
        common: :timer.seconds(5),
        dev: :timer.seconds(1)
      ],

      articles_cache: [
        # keeps items forever
        common: [],
        # quick expiration in dev
        dev: [
          ttl_check: :timer.seconds(1),
          ttl: :timer.seconds(1)
        ]
      ],

      db_counter_save_interval: [
        common: :timer.seconds(10),
        test: 1
      ],

      rate_limiters: [
        common: [
          {:per_second, :timer.seconds(1)},
          {:per_minute, :timer.minutes(1)}
        ]
      ],
      rate_limited_operations: [
        common: [
          plug_logger: nil,
          limit_warn_log: {:per_second, 0},
          request_db_log: nil,
          geoip_query: {:per_second, 0},
          geolocation_reporter: nil
        ],

        prod: [
          plug_logger: {:per_second, 100},
          limit_warn_log: {:per_minute, 1},
          request_db_log: {:per_second, 10},
          geoip_query: {:per_second, 50},
          geolocation_reporter: {:per_second, 30}
        ]
      ]
    ]
  ]

  def all, do: unquote(
    for {app, settings} <- apps_settings do
      {
        app,
        for {name, value} <- settings do
          common_value = value[:common]
          specific_value = value[Mix.env] || common_value

          [{^app, [{^name, value}]}] =
            Mix.Config.merge(
              [{app, [{name, common_value}]}],
              [{app, [{name, specific_value}]}]
            )

          Macro.escape({name, value})
        end
        |> Enum.filter(&(not match?({_, nil}, &1)))
      }
    end
  )
end