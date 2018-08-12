defmodule Erlangelist.UsageStats do
  import EnvHelper
  alias Erlangelist.UsageStats

  def folder(), do: Erlangelist.db_path("usage_stats")

  def setting!(name), do: Keyword.fetch!(config(), name)

  defdelegate report(key, value), to: UsageStats.Server

  def start_link() do
    File.mkdir_p(folder())

    Supervisor.start_link(
      [
        UsageStats.Server,
        Erlangelist.UsageStats.Cleanup
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  @doc false
  def child_spec(_arg) do
    %{
      id: __MODULE__,
      type: :supervisor,
      start: {__MODULE__, :start_link, []}
    }
  end

  defp config() do
    [
      flush_interval: env_specific(prod: :timer.minutes(1), else: :timer.seconds(1)),
      cleanup_interval: env_specific(prod: :timer.hours(1), else: :timer.minutes(1)),
      retention: 7
    ]
  end
end
