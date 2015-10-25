defmodule Erlangelist.Metrics do
  def inc_spiral(metric_name, count \\ 1) do
    metric_name
    |> ensure_metric(:spiral, :one, timespan: Erlangelist.app_env!(:exometer_polling_interval))
    |> :exometer.update(count)
  end

  def sample_histogram(metric_name, value) do
    metric_name
    |> ensure_metric(:histogram, [50, 75, 90, 95, :max], truncate: false)
    |> :exometer.update(value)
  end

  def measure(metric_name, fun) do
    inc_spiral(metric_name ++ [:count])

    start_time = :os.timestamp
    try do
      fun.()
    after
      end_time = :os.timestamp
      diff = :timer.now_diff(end_time, start_time)
      sample_histogram(metric_name ++ [:time], diff / 1000)
    end
  end

  defp ensure_metric(
    metric_name,
    metric_type,
    datapoint,
    metric_opts
  ) do
    metric_name = [:erlangelist | metric_name]
    ConCache.get_or_store(:metrics_cache, metric_name, fn ->
      :exometer.new(metric_name, metric_type, metric_opts)
      :exometer_report.subscribe(:exometer_report_statsd,
        metric_name, datapoint, Erlangelist.app_env!(:exometer_polling_interval))
      true
    end)
    metric_name
  end
end