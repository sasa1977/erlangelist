defmodule ErlangelistWeb.SiteController do
  use ErlangelistWeb, :controller

  def privacy_policy(conn, _params) do
    render(conn, "privacy.html", %{cookies: conn.cookies["cookies"] == "true"})
  end
end
