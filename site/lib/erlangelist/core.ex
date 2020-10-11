defmodule Erlangelist.Core do
  use Boundary, deps: [Erlangelist.Config], exports: [Article]
  use Parent.Supervisor

  alias Erlangelist.Core.UsageStats

  def start_link(_) do
    Parent.Supervisor.start_link(
      [
        UsageStats,
        {Phoenix.PubSub, name: Erlangelist.PubSub}
      ],
      name: __MODULE__
    )
  end
end
