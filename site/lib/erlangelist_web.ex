defmodule ErlangelistWeb do
  def start_link do
    Erlangelist.Backup.resync(ErlangelistWeb.Blog.SSL.certbot_folder())

    Supervisor.start_link(
      [ErlangelistWeb.Blog, ErlangelistWeb.Dashboard],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  def config_change(changed, removed) do
    ErlangelistWeb.Blog.Endpoint.config_change(changed, removed)
    ErlangelistWeb.Dashboard.Endpoint.config_change(changed, removed)
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
