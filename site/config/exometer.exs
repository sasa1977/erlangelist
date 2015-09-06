use Mix.Config

app_name         = :erlangelist
polling_interval = :timer.seconds(60)
histogram_stats  = ~w(median 75 90 95 max)a
memory_stats     = ~w(atom binary ets processes total)a

config :exometer,
  predefined: [
    {
      ~w(erlang memory)a,
      {:function, :erlang, :memory, [], :proplist, memory_stats},
      []
    },
    {
      ~w(erlang statistics)a,
      {:function, :erlang, :statistics, [:'$dp'], :value, [:run_queue]},
      []
    },
    {[app_name, :site, :requests], :spiral, []},
    {[app_name, :site, :response_time], :histogram, [truncate: false]},
  ],

  reporters: [
    exometer_report_statsd: [
      hostname: '127.0.0.1',
      port: 5457
    ],
  ],

  report: [
    subscribers: [
      {
        :exometer_report_statsd,
        [:erlang, :memory], memory_stats, polling_interval, true
      },
      {
        :exometer_report_statsd,
        [app_name, :site, :requests], :one, polling_interval, true
      },
      {
        :exometer_report_statsd,
        [app_name, :site, :response_time], histogram_stats, polling_interval, true
      }
    ]
  ]