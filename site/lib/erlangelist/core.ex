defmodule Erlangelist.Core do
  use Boundary, deps: [Erlangelist.Config], exports: [Article, Backup, UsageStats]
  use Parent.Supervisor

  def start_link(_) do
    Erlangelist.Core.Backup.resync(Erlangelist.Core.UsageStats.folder())

    Parent.Supervisor.start_link(
      [
        Erlangelist.Core.UsageStats,
        {Phoenix.PubSub, name: Erlangelist.PubSub}
      ],
      name: __MODULE__
    )
  end
end
