defmodule Erlangelist.Web do
  use Boundary, deps: [Erlangelist.{Core, Config}, Phoenix]

  def start_link do
    Parent.Supervisor.start_link(
      [Erlangelist.Web.Blog, Erlangelist.Web.Dashboard],
      name: __MODULE__
    )
  end

  def config_change(changed, removed) do
    Erlangelist.Web.Blog.Endpoint.config_change(changed, removed)
    Erlangelist.Web.Dashboard.Endpoint.config_change(changed, removed)
  end

  @doc false
  def child_spec(_) do
    %{
      id: __MODULE__,
      type: :supervisor,
      start: {__MODULE__, :start_link, []}
    }
  end
end
