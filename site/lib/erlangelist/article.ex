defmodule Erlangelist.Article do
  @external_resource "articles/index.exs"

  months = ~w(January February March April May June July August September October November December)
  days_abbr = ~w(Mon Tue Wed Thu Fri Sat Sun)
  months_abbr = Enum.map(months, &String.slice(&1, 0..2))

  to_rfc822 = fn date ->
    dow = Enum.at(days_abbr, Date.day_of_week(date) - 1)
    mon = Enum.at(months_abbr, date.month - 1)
    year = rem(date.year, 100)
    "#{dow}, #{date.day} #{mon} #{year} 00:00:00 +0000"
  end

  date_to_string = fn date -> "#{Enum.at(months, date.month - 1)} #{date.day}, #{date.year}" end

  article_meta = fn {article_id, article_spec} ->
    Application.ensure_all_started(:timex)

    date = Date.from_iso8601!(article_spec[:posted_at])

    Enum.into(article_spec, %{
      id: article_id,
      posted_at: date_to_string.(date),
      copyright_year: date.year,
      posted_at_rfc822: to_rfc822.(date),
      has_content?: article_spec[:redirect] == nil,
      long_title: article_spec[:long_title] || article_spec[:short_title],
      short_title: article_spec[:short_title] || article_spec[:long_title],
      link: article_spec[:redirect] || "/article/#{article_id}",
      redirect: article_spec[:redirect],
      source_link: "https://github.com/sasa1977/erlangelist/tree/master/site/articles/#{article_id}.md"
    })
  end

  {articles_specs, _} = Code.eval_file("articles/index.exs")
  articles_meta = Enum.map(articles_specs, article_meta)

  def all, do: unquote(Macro.escape(articles_meta))
  def most_recent, do: unquote(Macro.escape(hd(articles_meta)))

  for article <- articles_meta do
    def article(unquote(article.id)), do: unquote(Macro.escape(article))

    if article.has_content? do
      @external_resource "articles/#{article.id}.md"

      def html(%{id: unquote(article.id)}),
        do:
          unquote(
            "articles/#{article.id}.md"
            |> File.read!()
            |> Earmark.as_html!()
          )
    end
  end

  def article(_), do: nil

  def id_from_string(string) do
    try do
      String.to_existing_atom(string)
    rescue
      ArgumentError ->
        :undefined
    end
  end
end
