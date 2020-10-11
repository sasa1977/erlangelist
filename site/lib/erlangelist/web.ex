defmodule Erlangelist.Web do
  use Boundary, deps: [Erlangelist.{Core, Config}, Phoenix]
  use Parent.Supervisor

  alias Erlangelist.Web.{Blog, Dashboard}

  def start_link(_) do
    Parent.Supervisor.start_link(
      [Blog, Dashboard],
      name: __MODULE__
    )
  end

  def config_change(changed, removed) do
    Blog.Endpoint.config_change(changed, removed)
    Dashboard.Endpoint.config_change(changed, removed)
  end
end
