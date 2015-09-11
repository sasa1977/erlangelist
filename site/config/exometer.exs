use Mix.Config

polling_interval = case Mix.env do
  :dev -> :timer.seconds(1)
  _ -> :timer.seconds(60)
end

memory_stats = ~w(atom binary ets processes total)a

config :erlangelist,
  polling_interval: polling_interval

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
    }
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
        [:erlang, :memory], memory_stats, polling_interval
      }
    ]
  ]