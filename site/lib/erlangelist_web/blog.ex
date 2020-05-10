defmodule ErlangelistWeb.Blog do
  @doc false
  def child_spec(_),
    do: SiteEncrypt.Phoenix.child_spec(ErlangelistWeb.Blog.Endpoint)
end
