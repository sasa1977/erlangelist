defmodule Erlangelist.Web.Blog do
  use Boundary, exports: [Endpoint], deps: [Erlangelist.Web.Plug]

  @doc false
  def child_spec(_),
    do: SiteEncrypt.Phoenix.child_spec(Erlangelist.Web.Blog.Endpoint)
end
