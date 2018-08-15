defmodule Erlangelist.UsageStats do
  alias Erlangelist.UsageStats

  def folder(), do: Erlangelist.db_path("usage_stats")

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
end
