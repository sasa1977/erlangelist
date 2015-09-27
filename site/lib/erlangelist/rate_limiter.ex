defmodule Erlangelist.RateLimiter do
  use ExActor.GenServer

  require Logger

  defstart start(limiter_name, interval)
  defstart start_link(limiter_name, interval) do
    :ets.new(
      limiter_name,
      [:named_table, :public, read_concurrency: true, write_concurrency: true]
    )

    timeout_after(interval)
    initial_state(limiter_name)
  end

  defhandleinfo :timeout, state: limiter_name do
    :ets.delete_all_objects(limiter_name)
    noreply
  end

  def allow?(limiter_name, operation_name, max_rate) do
    cnt = :ets.update_counter(limiter_name, operation_name, 1, {operation_name, 0})
    cnt <= max_rate
  end
end