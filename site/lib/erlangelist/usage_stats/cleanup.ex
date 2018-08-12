defmodule Erlangelist.UsageStats.Cleanup do
  alias Erlangelist.UsageStats

  defp cleanup() do
    with {:ok, files} <- File.ls(UsageStats.folder()) do
      files
      |> Enum.sort()
      |> Enum.reverse()
      |> Enum.drop(UsageStats.setting!(:retention))
      |> Stream.map(&Path.join(UsageStats.folder(), &1))
      |> Enum.each(&File.rm/1)
    end
  end

  @doc false
  def child_spec(_arg) do
    Periodic.child_spec(
      id: __MODULE__,
      run: &cleanup/0,
      every: UsageStats.setting!(:cleanup_interval),
      overlap?: false
    )
  end
end
