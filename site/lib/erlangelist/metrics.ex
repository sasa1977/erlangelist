defmodule Erlangelist.Metrics do
  def inc_spiral(metric_name, count \\ 1) do
    metric_name
    |> ensure_metric(:spiral, :one)
    |> :exometer.update(count)
  end

  def sample_histogram(metric_name, value) do
    metric_name
    |> ensure_metric(:histogram, [:median, 75, 90, 95, :max], truncate: false)
    |> :exometer.update(value)
  end

  defp ensure_metric(
    metric_name,
    metric_type,
    datapoint,
    metric_opts \\ []
  ) do
    metric_name = [:erlangelist | metric_name]
    ConCache.get_or_store(:metrics, metric_name, fn ->
      {:ok, polling_interval} = Application.fetch_env(:erlangelist, :polling_interval)
      :exometer.new(metric_name, metric_type, metric_opts)
      :exometer_report.subscribe(:exometer_report_statsd, metric_name, datapoint, polling_interval)
      true
    end)
    metric_name
  end
end