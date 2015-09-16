defmodule Erlangelist.Settings do
  apps_settings = [
    kernel: [
      inet_dist_listen_min: [common: 30000],
      inet_dist_listen_max: [common: 30000]
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

    erlangelist: [
      {Erlangelist.Endpoint.Site,
        common: [
          url: [host: "localhost"],
          http: [port: 5454],
          root: Path.dirname(__DIR__),
          secret_key_base: "ija3ahutZFpFyiWJLfLX9uJ1MGVv5knZDT1cxEY+1cbkAdnw3R858Xhdk2lIgxOh",
          render_errors: [accepts: ~w(html json)],
          pubsub: [name: Erlangelist.PubSub, adapter: Phoenix.PubSub.PG2],
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

      {Erlangelist.Repo,
        common: [
          adapter: Ecto.Adapters.Postgres,
          database: "erlangelist",
          username: "erlangelist",
          password: "",
          hostname: "127.0.0.1",
          port: 5432
        ],

        prod: [
          hostname: "172.17.42.1",
          port: 5459
        ]
      },

      peer_ip: [
        common: "127.0.0.1",
        prod: "172.17.42.1"
      ],

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

      article_event_handlers: [
        common: [Erlangelist.ArticleEvent.Metrics],
        test: []
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