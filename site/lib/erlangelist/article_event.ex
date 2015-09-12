defmodule Erlangelist.ArticleEvent do
  def start_link do
    res = GenEvent.start_link(name: :article_event)
    if match?({:ok, _}, res), do: install_handlers
    res
  end

  defp install_handlers do
    for event_handler <- Erlangelist.app_env!(:article_event_handlers) do
      GenEvent.add_handler(:article_event, event_handler, nil)
    end
  end

  def visited(article, data) do
    GenEvent.notify(:article_event, {:article_visited, article, data})
  end

  def invalid_article do
    GenEvent.notify(:article_event, :invalid_article)
  end
end