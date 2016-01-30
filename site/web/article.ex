defmodule Erlangelist.Article do
  @external_resource "articles/index.exs"

  article_meta = fn({article_id, article_spec}) ->
    date = Timex.DateFormat.parse!(article_spec[:posted_at], "{ISOdate}")

    Enum.into(article_spec,
      %{
        id: article_id,
        posted_at: Timex.DateFormat.format!(date, "%B %d, %Y", :strftime),
        copyright_year: date.year,
        posted_at_rfc822: Timex.DateFormat.format!(date, "{RFC822}"),
        has_content?: article_spec[:redirect] == nil,
        long_title: article_spec[:long_title] || article_spec[:short_title],
        short_title: article_spec[:short_title] || article_spec[:long_title],
        link: article_spec[:redirect] || "/article/#{article_id}",
        redirect: article_spec[:redirect],
        legacy_url: article_spec[:legacy_url] || nil,
        source_link: "https://github.com/sasa1977/erlangelist/tree/master/site/articles/#{article_id}.md"
      }
    )
  end


  {articles_specs, _} = Code.eval_file("articles/index.exs")
  articles_meta = Enum.map(articles_specs, article_meta)

  def all, do: unquote(Macro.escape(articles_meta))
  def most_recent, do: unquote(Macro.escape(hd(articles_meta)))

  for article <- articles_meta do
    def article(unquote(article.id)), do: unquote(Macro.escape(article))

    if article.has_content? do
      @external_resource "articles/#{article.id}.md"

      def html(%{id: unquote(article.id)}), do:
        unquote(
          "articles/#{article.id}.md"
          |> File.read!
          |> Earmark.to_html
        )
    end
  end

  def article(_), do: nil

  def id_from_string(string) do
    try do
      String.to_existing_atom(string)
    rescue ArgumentError ->
      :undefined
    end
  end
end
