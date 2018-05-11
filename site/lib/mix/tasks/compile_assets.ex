defmodule Mix.Tasks.Erlangelist.CompileAssets do
  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    {:ok, cwd} = File.cwd()
    brunch_bin = Path.join([cwd, "assets/node_modules/brunch/bin/brunch"])

    {_output, status} =
      System.cmd(
        brunch_bin,
        ["build", "--production"],
        cd: "assets",
        into: IO.stream(:stdio, :line),
        stderr_to_stdout: true
      )

    if status != 0, do: Mix.raise("assets compilation failed")
  end
end
