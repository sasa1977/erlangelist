defmodule Erlangelist.RateLimiter do
  use ExActor.GenServer

  require Logger

  defstart start(limiter_name, interval)
  defstart start_link(limiter_name, interval) do
    :ets.new(
      limiter_name,
      [:named_table, :public, read_concurrency: true, write_concurrency: true]
    )

    :timer.send_interval(interval, :purge_counts)

    initial_state(limiter_name)
  end

  defhandleinfo :purge_counts, state: limiter_name do
    :ets.delete_all_objects(limiter_name)
    noreply
  end

  def allow?(limiter_name, operation_name, max_rate) do
    cnt = :ets.update_counter(
      limiter_name,
      operation_name,
      {2, 1, max_rate, max_rate+1},
      {operation_name, 0}
    )
    cnt <= max_rate
  end
end