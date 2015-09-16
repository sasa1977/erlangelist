defmodule Erlangelist.AdminController do
  use Phoenix.Controller
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo
  alias Erlangelist.Model.ArticleVisit

  plug :set_layout

  def set_layout(conn, _params) do
    put_layout(conn, {Erlangelist.LayoutView, :admin})
  end

  def index(conn, _params) do
    max_visits = Repo.all(
      from visit in grouped_visits,
      select: [visit.name, max(visit.value)],
      order_by: [desc: max(visit.value)]
    )

    render(conn, "index.html", %{article_visits: [
      recent: article_visits(max_visits, hours: -2),
      day: article_visits(max_visits, days: -1),
      month: article_visits(max_visits, months: -1),
      total: article_visits(max_visits)
    ]})
  end

  defp article_visits(max_visits, span \\ nil) do
    past_visits =
      if span do
        {:ok, since} =
          Timex.Date.now
          |> Timex.Date.shift(span)
          |> Timex.Ecto.DateTime.dump

        Repo.all(
          from pc in grouped_visits,
          select: [pc.name, max(pc.value)],
          where: pc.created_at < ^since
        )
        |> Stream.map(&List.to_tuple/1)
        |> Enum.into(%{})
      else
        %{}
      end

    Stream.map(max_visits, fn([name, count]) ->
      past_count = past_visits[name] || 0
      {name, count - past_count}
    end)
    |> Stream.filter(fn({_, count}) -> count > 0 end)
  end

  defp grouped_visits do
    from visit in ArticleVisit,
      group_by: [visit.name]
  end
end