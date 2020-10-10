defmodule Erlangelist.Web.Blog do
  @doc false
  def child_spec(_),
    do: SiteEncrypt.Phoenix.child_spec(Erlangelist.Web.Blog.Endpoint)
end
