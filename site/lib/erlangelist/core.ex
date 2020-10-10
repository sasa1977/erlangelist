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

  @doc false
  def child_spec(_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []},
      type: :supervisor
    }
  end
end
