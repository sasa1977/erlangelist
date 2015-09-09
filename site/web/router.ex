defmodule Erlangelist.Router do
  require Erlangelist.Article
  use Erlangelist.Web, :router

  pipeline :browser do
    plug Erlangelist.Exometer.Visit
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", Erlangelist do
    pipe_through :browser # Use the default browser stack

    get "/", ArticleController, :most_recent
    get "/article/:article_id", ArticleController, :article


    for {article_id, meta} <- Erlangelist.Article.all do
      # old-style urls
      if path = meta[:legacy_url] do
        get path, ArticleController, :article, private: %{article_id: article_id}
      end

      # redirect to blogspot for non-migrated articles
      if path = meta[:redirect] do
        get String.replace(path, "http://theerlangelist.blogspot.com",""), OldPostController, :render
      end
    end
  end

  scope "/", Erlangelist do
    get "/rss", RssController, :index
    get "/feeds/posts/default", RssController, :index
  end
end
