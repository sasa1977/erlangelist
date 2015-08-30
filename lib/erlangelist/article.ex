defmodule Erlangelist.Article do
  use ExActor.GenServer
  require Logger

  def articles do
    ConCache.get_or_store(:articles, :articles_metas, fn ->
      {articles_meta, _} = Code.eval_file("#{Application.app_dir(:erlangelist, "priv")}/articles.exs")
      for {article_id, meta} <- articles_meta do
        {
          article_id,
          Enum.map(meta, fn
            {:posted_at, isodate} ->
              {:ok, date} = Timex.DateFormat.parse(isodate, "{ISOdate}")
              {:ok, formatted_date} = Timex.DateFormat.format(date, "%B %d, %Y", :strftime)
              {:posted_at, formatted_date} |> IO.inspect

            other -> other
          end)
        }
      end
    end)
  end

  def most_recent do
    article(hd(articles))
  end

  def get(article_id) do
    ConCache.get_or_store(:articles, {:article_meta, article_id}, fn ->
      Enum.find(articles, &match?({^article_id, _}, &1))
    end)
    |> article
  end

  defp article(nil), do: nil
  defp article({article_id, meta}) do
    ConCache.get_or_store(:articles, {:article_data, article_id}, fn ->
      %ConCache.Item{
        value: [{:html, article_html(article_id)} | meta],
        ttl: :timer.minutes(30)
      }
    end)
  end

  defp article_html(article_id) do
    "#{priv_dir}/articles/#{article_id}.md"
    |> File.read!
    |> Earmark.to_html
  end


  defstart start_link do
    :fs.subscribe

    initial_state(%{
        regexes: [
          articles: Regex.compile!("^#{priv_regex("articles.exs")}$"),
          article: Regex.compile!("^#{priv_regex("articles")}/(?<article_id>.+)\.md$")
        ]
    })
  end


  defhandleinfo {_, {:fs, :file_event}, {path, [_, :modified]}}, state: state do
    path = to_string(path)

    state.regexes
    |> Stream.map(fn({regex_id, regex}) -> {regex_id, Regex.named_captures(regex, path)} end)
    |> Enum.find(fn({_, matches}) -> matches != nil end)
    |> case do
      nil -> :ok

      {:articles, %{}} ->
        Logger.info("invalidating cache for articles metas")
        ConCache.delete(:articles, :articles_metas)

      {:article, %{"article_id" => article_id}} ->
        Logger.info("invalidating cache for article #{article_id}")
        ConCache.delete(:articles, {:article_meta, article_id})
        ConCache.delete(:articles, {:article_data, article_id})
    end

    noreply
  end

  defhandleinfo _, do: noreply


  defp priv_regex(path) do
    priv_dir
    |> Path.join(path)
    |> Regex.escape
  end

  if Mix.env != "prod" do
    defp priv_dir, do: "#{File.cwd!}/priv"
  else
    defp priv_dir, do: Application.app_dir(:erlangelist, "priv")
  end
end