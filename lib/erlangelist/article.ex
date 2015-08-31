defmodule Erlangelist.Article do
  use ExActor.GenServer
  require Logger

  def all do
    ConCache.get_or_store(:articles, :articles_metas, fn ->
      {articles_meta, _} = Code.eval_file("#{Application.app_dir(:erlangelist, "priv")}/articles.exs")
      Enum.map(articles_meta, &transform_meta/1)
    end)
  end

  defp transform_meta({article_id, meta}) do
    transformed_meta =
      meta
      |> Enum.map(fn
        {:posted_at, isodate} ->
          {:ok, date} = Timex.DateFormat.parse(isodate, "{ISOdate}")
          {:ok, formatted_date} = Timex.DateFormat.format(date, "%B %d, %Y", :strftime)
          {:posted_at, formatted_date}

        {:redirect, old_link} ->
          {:redirect, "http://theerlangelist.blogspot.com#{old_link}"}

        other -> other
      end)
      |> Enum.into(%{})
      |> Map.put(:id, article_id)

    {article_id, transformed_meta}
  end

  def most_recent do
    case all do
      [] -> nil
      [{_, meta} | _] -> meta
    end
  end

  def meta(article_id) do
    case ConCache.get_or_store(:articles, {:article_meta, article_id}, fn ->
      Enum.find(all, &match?({^article_id, _}, &1))
    end) do
      nil -> nil
      {_, meta} -> meta
    end
  end

  def html(article_id) do
    "#{priv_dir}/articles/#{article_id}.md"
    |> File.read!
    |> Earmark.to_html
  end

  def link({_, %{redirect: redirect}}), do: redirect
  def link({article_id, _meta}) do
    "/article/#{article_id}"
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
        ConCache.delete(:articles, {:article_html, :last})

      {:article, %{"article_id" => article_id}} ->
        Logger.info("invalidating cache for article #{article_id}")
        ConCache.delete(:articles, {:article_meta, article_id})
        ConCache.delete(:articles, {:article_html, article_id})
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