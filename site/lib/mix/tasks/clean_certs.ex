defmodule Mix.Tasks.Erlangelist.Clean do
  use Mix.Task

  # Mix.Task behaviour is not in PLT since Mix is not a runtime dep, so we disable the warning
  @dialyzer :no_undefined_callbacks

  @impl Mix.Task
  def run(_) do
    Enum.each(
      [
        ErlangelistWeb.Blog.Endpoint.certbot_folder(),
        ErlangelistWeb.Blog.Endpoint.cert_folder(),
        Erlangelist.UsageStats.folder(),
        Erlangelist.Backup.folder()
      ],
      &File.rm_rf/1
    )
  end
end
