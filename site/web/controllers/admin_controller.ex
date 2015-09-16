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
    render(conn, "index.html", %{article_views: article_views(hours: -2)})
  end

  defp article_views(span) do
    {:ok, since} =
      Timex.Date.now
      |> Timex.Date.shift(span)
      |> Timex.Ecto.DateTime.dump

    past_views =
      Repo.all(
        from pc in grouped_views(since),
        select: [pc.name, min(pc.value)]
      )
      |> Stream.map(&List.to_tuple/1)
      |> Enum.into(%{})

    Repo.all(
      from pc in grouped_views(since),
      select: [pc.name, max(pc.value)],
      order_by: [desc: max(pc.value)]
    )
    |> Stream.map(fn([name, count]) ->
         past_count = past_views[name] || 0
         {name, count - past_count}
       end)
  end

  defp grouped_views(since) do
    from pc in PersistentCounter,
      group_by: [pc.name],
      where:
        pc.category == "article_view"
        and pc.created_at >= ^since
  end
end