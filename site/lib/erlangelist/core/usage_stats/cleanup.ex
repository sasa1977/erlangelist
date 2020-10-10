defmodule Erlangelist.Core.UsageStats.Cleanup do
  # This code is mostly a verbatim copy of the ex_doc highlighter
  # (https://github.com/elixir-lang/ex_doc/blob/d5cde30f55c7e0cde486ec3878067aee82ccc924/lib/ex_doc/highlighter.ex)
  alias Erlangelist.Core.UsageStats

  defp cleanup() do
    with {:ok, files} <- File.ls(UsageStats.folder()) do
      for file <- files,
          week_ago = Date.add(UsageStats.utc_today(), -7),
          date = from_yyyymmdd!(file),
          Date.compare(date, week_ago) in [:lt, :eq],
          do: File.rm(Path.join(UsageStats.folder(), file))
    end
  end

  @doc false
  def from_yyyymmdd!(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>),
    do: Date.from_iso8601!(Enum.join([y, m, d], "-"))

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
