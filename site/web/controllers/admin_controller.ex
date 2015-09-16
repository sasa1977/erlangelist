defmodule Erlangelist.AdminController do
  use Phoenix.Controller
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo
  alias Erlangelist.Model.PersistentCounter

  plug :set_layout

  def set_layout(conn, _params) do
    put_layout(conn, {Erlangelist.LayoutView, :admin})
  end

  def index(conn, _params) do
    max_views = Repo.all(
      from pc in grouped_views,
      select: [pc.name, max(pc.value)],
      order_by: [desc: max(pc.value)]
    )

    render(conn, "index.html", %{article_views: [
      recent: article_views(max_views, hours: -2),
      day: article_views(max_views, days: -1),
      month: article_views(max_views, months: -1),
      total: article_views(max_views)
    ]})
  end

  defp article_views(max_views, span \\ nil) do
    past_views =
      if span do
        {:ok, since} =
          Timex.Date.now
          |> Timex.Date.shift(span)
          |> Timex.Ecto.DateTime.dump

        Repo.all(
          from pc in grouped_views,
          select: [pc.name, min(pc.value)],
          where: pc.created_at >= ^since
        )
        |> Stream.map(&List.to_tuple/1)
        |> Enum.into(%{})
      else
        %{}
      end

    Stream.map(max_views, fn([name, count]) ->
      past_count = past_views[name] || 0
      {name, count - past_count}
    end)
  end

  defp grouped_views do
    from pc in PersistentCounter,
      group_by: [pc.name],
      where: pc.category == "article_view"
  end
end