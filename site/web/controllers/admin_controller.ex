defmodule Erlangelist.AdminController do
  use Phoenix.Controller
  alias Erlangelist.Analytics

  plug :set_layout

  def set_layout(conn, _params) do
    put_layout(conn, {Erlangelist.LayoutView, :admin})
  end

  def index(conn, _params) do
    render(conn, "index.html", all_visits: Analytics.all)
  end


  def drilldown(conn, params) do
    render(conn, "drilldown.html", %{
      title: "#{params["type"]}(#{params["key"]}) / #{params["period"]}",
      rows: Analytics.drilldown(
        String.to_existing_atom(params["type"]),
        params["key"],
        params["period"]
      )
    })
  end


end