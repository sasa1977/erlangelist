defmodule Erlangelist.Core.UsageStats.Cleanup do
  alias Erlangelist.Core.UsageStats

  defp cleanup() do
    with {:ok, files} <- File.ls(UsageStats.folder()) do
      for file <- files,
          week_ago = Date.add(Erlangelist.Date.utc_today(), -7),
          date = Erlangelist.Date.from_yyyymmdd!(file),
          Date.compare(date, week_ago) in [:lt, :eq],
          do: File.rm(Path.join(UsageStats.folder(), file))
    end
  end

  @doc false
  def child_spec(_arg) do
    Periodic.child_spec(
      id: __MODULE__,
      name: __MODULE__,
      run: &cleanup/0,
      initial_delay: :timer.seconds(5),
      every: :timer.hours(1),
      on_overlap: :stop_previous,
      mode: unquote(if(Mix.env() == :test, do: :manual, else: :auto))
    )
  end
end
