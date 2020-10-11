defmodule Erlangelist.Core.UsageStats do
  use Boundary, deps: [Erlangelist.Core.Backup]
  use Parent.Supervisor

  alias Erlangelist.Core.{Backup, UsageStats}

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
    Backup.resync(folder())
    File.mkdir_p(folder())

    Parent.Supervisor.start_link(
      [
        UsageStats.Server,
        cleanup_spec()
      ],
      name: __MODULE__
    )
  end

  def utc_today, do: @date_provider.utc_today

  def clear_all do
    {:ok, stopped_children} = Parent.Client.shutdown_child(__MODULE__, UsageStats.Server)
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

  ## Periodic cleanup

  defp cleanup_spec do
    Periodic.child_spec(
      id: __MODULE__.Cleanup,
      name: __MODULE__.Cleanup,
      run: &cleanup/0,
      initial_delay: :timer.seconds(5),
      every: :timer.hours(1),
      on_overlap: :stop_previous,
      mode: unquote(if(Mix.env() == :test, do: :manual, else: :auto))
    )
  end

  defp cleanup do
    with {:ok, files} <- File.ls(folder()) do
      for file <- files,
          week_ago = Date.add(utc_today(), -7),
          date = from_yyyymmdd!(file),
          Date.compare(date, week_ago) in [:lt, :eq],
          do: File.rm(Path.join(folder(), file))
    end
  end

  @doc false
  def from_yyyymmdd!(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>),
    do: Date.from_iso8601!(Enum.join([y, m, d], "-"))

  defp folder, do: Erlangelist.Config.usage_stats_folder()
end
