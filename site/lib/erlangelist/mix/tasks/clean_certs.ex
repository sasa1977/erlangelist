defmodule Mix.Tasks.Erlangelist.Clean do
  use Boundary, classify_to: Erlangelist.Mix
  use Mix.Task

  # Mix.Task behaviour is not in PLT since Mix is not a runtime dep, so we disable the warning
  @dialyzer :no_undefined_callbacks

  @impl Mix.Task
  def run(_) do
    Enum.each(
      [
        Erlangelist.Core.Backup.folder(),
        Erlangelist.Config.db_path([])
      ],
      &File.rm_rf/1
    )
  end
end
