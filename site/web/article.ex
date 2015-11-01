defmodule Erlangelist.Article do
  @external_resource "articles/index.exs"

  article_map = fn({article_id, data}) ->
    date = Timex.DateFormat.parse!(data[:posted_at], "{ISOdate}")

    transformed_meta =
      data
      |> Enum.into(%{})
      |> Map.put(:id, article_id)
      |> Map.put(:posted_at, Timex.DateFormat.format!(date, "%B %d, %Y", :strftime))
      |> Map.put(:posted_at_rfc822, Timex.DateFormat.format!(date, "{RFC822}"))
      |> Map.put(:has_content?, data[:redirect] == nil)
      |> Map.put(:long_title, data[:long_title] || data[:short_title])
      |> Map.put(:short_title, data[:short_title] || data[:long_title])
      |> Map.put(:link, data[:redirect] || "/article/#{article_id}")
      |> Map.put(:redirect, data[:redirect])
      |> Map.put(:legacy_url, data[:legacy_url] || nil)
      |> Map.put(:source_link, "https://github.com/sasa1977/erlangelist/tree/master/site/articles/#{article_id}.md")

    transformed_meta
  end

  html = fn(article_id) ->
    "articles/#{article_id}.md"
    |> File.read!
    |> Earmark.to_html
  end



  {articles_data, _} = Code.eval_file("articles/index.exs")

  for {article_id, _} <- articles_data, do: @external_resource "articles/#{article_id}.md"

  ordered_articles = Enum.map(articles_data, article_map)
  def all do
    unquote(Macro.escape(ordered_articles))
  end

  def most_recent do
    unquote(Macro.escape(hd(ordered_articles)))
  end

  for article <- ordered_articles do
    def article(unquote(article.id)), do: unquote(Macro.escape(article))

    if article.has_content? do
      def html(%{id: unquote(article.id)}), do: unquote(html.(article.id))
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