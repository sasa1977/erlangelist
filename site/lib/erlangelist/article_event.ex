defmodule Erlangelist.ArticleEvent do
  def manager_name, do: :article_event

  def start_link do
    res = GenEvent.start_link(name: manager_name)
    if match?({:ok, _}, res), do: install_handlers
    res
  end

  defp install_handlers do
    for event_handler <- Erlangelist.app_env!(:article_event_handlers) do
      GenEvent.add_mon_handler(manager_name, event_handler, nil)
    end
  end

  def visited(article, conn) do
    notify({:article_visited, article, data(conn)})
  end

  def invalid_article do
    notify(:invalid_article)
  end

  defp notify(event) do
    Erlangelist.run_limited(
      :article_events,
      fn -> GenEvent.notify(manager_name, event) end
    )
  end

  defp data(conn) do
    %{
      remote_ip: conn.remote_ip,
      referer: Plug.Conn.get_req_header(conn, "referer")
    }
  end
end