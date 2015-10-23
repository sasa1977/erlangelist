use Mix.Config

memory_stats = ~w(atom binary ets processes total)a

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
      hostname: '#{Erlangelist.Settings.all[:erlangelist][:peer_ip]}',
      port: Erlangelist.SystemSettings.value(:statsd_port)
    ],
  ],

  report: [
    subscribers: [
      {
        :exometer_report_statsd,
        [:erlang, :memory],
        memory_stats,
        Erlangelist.Settings.all[:erlangelist][:exometer_polling_interval]
      }
    ]
  ]