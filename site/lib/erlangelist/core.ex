defmodule Erlangelist.Core do
  use Boundary, deps: [Erlangelist.Config], exports: [Article, Backup, UsageStats]

  def start_link do
    Erlangelist.Core.Backup.resync(Erlangelist.Core.UsageStats.folder())

    Parent.Supervisor.start_link(
      [
        Erlangelist.Core.UsageStats,
        {Phoenix.PubSub, name: Erlangelist.PubSub}
      ],
      name: __MODULE__
    )
  end

  def priv_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv") | parts])
  def priv_path(name), do: priv_path([name])

  def db_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv"), "db" | parts])
  def db_path(name), do: db_path([name])

  @doc false
  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end
end
