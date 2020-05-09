defmodule ErlangelistWeb.BlogTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  alias Erlangelist.Article
  alias ErlangelistTest.Client

  test "root page shows the most recent article" do
    assert response(Client.get("/"), 200) =~ "<h1>#{Plug.HTML.html_escape(Article.most_recent().long_title)}</h1>"
  end

  for article <- Article.all(), article.has_content? do
    test "shows the #{article.id} article" do
      assert response(Client.article(unquote(article.id)), 200) =~
               "<h1>#{Plug.HTML.html_escape(unquote(article.long_title))}</h1>"
    end
  end

  test "renders not found for unknown article" do
    assert response(Client.article("unknown_article"), 404) =~ "Page not found"
  end

  test "serves rss feed" do
    response = response(Client.rss_feed(), 200)

    for article <- Article.all(), article.has_content? do
      assert response =~ "<h1>#{Plug.HTML.html_escape(article.long_title)}</h1>"
    end
  end

  @tag :certification
  test "certificate is renewed at midnight UTC" do
    original_cert = get_cert()

    log =
      capture_log(fn ->
        assert SiteEncrypt.Certifier.tick_at(ErlangelistWeb.Blog.Certifier, ~U[2020-01-01 00:00:00Z]) == :ok
      end)

    assert log =~ "Obtained new certificate for localhost"
    assert get_cert() != original_cert
  end

  test "http requests are redirected to https" do
    assert redirected_to(Client.get("http://localhost/"), 301) == "https://localhost/"
  end

  test "theerlangelist.com is redirected to www.theerlangelist.com" do
    assert redirected_to(Client.get("https://theerlangelist.com/"), 301) == "https://www.theerlangelist.com/"
  end

  defp get_cert do
    {:ok, socket} = :ssl.connect('localhost', 21443, [], :timer.seconds(5))
    {:ok, der_cert} = :ssl.peercert(socket)
    :ssl.close(socket)
    der_cert
  end

  defp capture_log(fun) do
    Logger.configure(level: :debug)
    ExUnit.CaptureLog.capture_log(fun)
  after
    Logger.configure(level: :warning)
  end
end
