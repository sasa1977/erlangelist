defmodule Erlangelist.Core.UsageStats do
  use Boundary, deps: [Erlangelist.Core.Backup]
  use Parent.Supervisor

  alias Erlangelist.Core.UsageStats

  defmodule DateProvider do
    @callback utc_today :: Date.t()
  end

  if Mix.env() != :test do
    @date_provider Date
  else
    @date_provider DateProvider.Mock

    Mox.defmock(@date_provider, for: DateProvider)

    def mock_today(date) do
      Mox.stub(@date_provider, :utc_today, fn -> date end)
      Mox.allow(@date_provider, self(), UsageStats.Server)
      Mox.allow(@date_provider, self(), UsageStats.Cleanup)
    end
  end

  def start_link(_) do
    File.mkdir_p(folder())

    Parent.Supervisor.start_link(
      [
        UsageStats.Server,
        Erlangelist.Core.UsageStats.Cleanup
      ],
      name: __MODULE__
    )
  end

  def utc_today, do: @date_provider.utc_today

  def folder, do: Erlangelist.Config.db_path("usage_stats")

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
    |> Enum.into(%{}, &{&1, folder() |> Path.join(&1) |> File.read!() |> :erlang.binary_to_term()})
  end
end
