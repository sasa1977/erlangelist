defmodule Erlangelist.UsageStats do
  alias Erlangelist.UsageStats

  def folder, do: Erlangelist.db_path("usage_stats")

  def clear_all do
    Supervisor.terminate_child(__MODULE__, Erlangelist.UsageStats.Server)
    File.rm_rf(folder())
    File.mkdir_p!(folder())
    Supervisor.restart_child(__MODULE__, Erlangelist.UsageStats.Server)
    :ok
  end

  defdelegate report(key, value), to: UsageStats.Server
  defdelegate sync(), to: UsageStats.Server

  def all do
    folder()
    |> File.ls!()
    |> Enum.into(%{}, fn filename ->
      {
        Erlangelist.Date.from_yyyymmdd!(filename),
        folder() |> Path.join(filename) |> File.read!() |> :erlang.binary_to_term()
      }
    end)
  end

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
