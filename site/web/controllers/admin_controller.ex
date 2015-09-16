defmodule Erlangelist.AdminController do
  use Phoenix.Controller
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo
  alias Erlangelist.Model.ArticleVisit
  alias Erlangelist.Model.CountryVisit
  alias Erlangelist.Model.RefererHostVisit
  alias Erlangelist.Model.RefererVisit

  plug :set_layout

  def set_layout(conn, _params) do
    put_layout(conn, {Erlangelist.LayoutView, :admin})
  end

  def index(conn, _params) do
    render(conn, "index.html", all_visits: all_visits)
  end

  @periods [
    recent: [hours: -2],
    day: [days: -1],
    month: [months: -1],
    all: nil
  ]

  @visit_types [
    article: ArticleVisit,
    country: CountryVisit,
    referer_host: RefererHostVisit,
    referer_url: RefererVisit
  ]

  defp all_visits do
    max_visits =
      for {_, model} <- @visit_types, into: %{} do
        {
          model,
          Repo.all(
            from visit in grouped_visits(model),
            select: [visit.key, max(visit.value)],
            order_by: [desc: max(visit.value)]
          )
        }
      end

    for {period_name, span} <- @periods do
      {
        period_name,
        for {visit_type, model} <- @visit_types do
          {visit_type, visit_data(max_visits, model, span)}
        end
      }
    end
  end

  defp visit_data(max_visits, model, span) do
    past_visits =
      if span do
        {:ok, since} =
          Timex.Date.now
          |> Timex.Date.shift(span)
          |> Timex.Ecto.DateTime.dump

        Repo.all(
          from visit in grouped_visits(model),
          select: [visit.key, max(visit.value)],
          where: visit.created_at < ^since
        )
        |> Stream.map(&List.to_tuple/1)
        |> Enum.into(%{})
      else
        %{}
      end

    Stream.map(max_visits[model], fn([key, count]) ->
      past_count = past_visits[key] || 0
      {key, count - past_count}
    end)
    |> Stream.filter(fn({_, count}) -> count > 0 end)
    |> Enum.sort_by(
          fn({name, count}) -> {-count, name} end,
          &<=/2
        )
    |> Enum.take(10)
  end

  defp grouped_visits(model) do
    from visit in model,
      group_by: [visit.key]
  end
end