defmodule Erlangelist.UsageStats.Cleanup do
  import EnvHelper
  alias Erlangelist.UsageStats

  @max_files 7
  @cleanup_interval env_specific(prod: :timer.hours(1), else: :timer.seconds(30))
  @cleanup_timeout @cleanup_interval - :timer.seconds(5)

  defp cleanup() do
    with {:ok, files} <- File.ls(UsageStats.folder()) do
      files
      |> Enum.sort()
      |> Enum.reverse()
      |> Stream.drop(@max_files)
      |> Stream.map(&Path.join(UsageStats.folder(), &1))
      |> Enum.each(&File.rm/1)
    end
  end

  @doc false
  def child_spec(_arg) do
    Periodic.child_spec(
      id: __MODULE__,
      run: &cleanup/0,
      initial_delay: :timer.seconds(5),
      every: @cleanup_interval,
      timeout: @cleanup_timeout,
      overlap?: false
    )
  end
end
