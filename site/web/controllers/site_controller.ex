defmodule Erlangelist.SiteController do
  use Erlangelist.Web, :controller

  def privacy_policy(conn, _params) do
    render(conn, "privacy.html", %{cookies: conn.cookies["cookies"] == "true"})
  end
end
