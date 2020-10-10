defmodule Erlangelist.Core.UsageStats do
  alias Erlangelist.Core.UsageStats

  def folder, do: Erlangelist.Core.db_path("usage_stats")

  def clear_all do
    {:ok, stopped_children} = Parent.Client.shutdown_child(__MODULE__, Erlangelist.Core.UsageStats.Server)
    File.rm_rf(folder())
    File.mkdir_p!(folder())
    Parent.Client.return_children(__MODULE__, stopped_children)
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

    Parent.Supervisor.start_link(
      [
        UsageStats.Server,
        Erlangelist.Core.UsageStats.Cleanup
      ],
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
