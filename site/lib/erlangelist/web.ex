defmodule Erlangelist.Web do
  use Boundary, deps: [Erlangelist.{Core, Config}, Phoenix]
  use Parent.Supervisor

  def start_link(_) do
    Parent.Supervisor.start_link(
      [Erlangelist.Web.Blog, Erlangelist.Web.Dashboard],
      name: __MODULE__
    )
  end

  def config_change(changed, removed) do
    Erlangelist.Web.Blog.Endpoint.config_change(changed, removed)
    Erlangelist.Web.Dashboard.Endpoint.config_change(changed, removed)
  end
end
