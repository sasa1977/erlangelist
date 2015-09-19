defmodule Erlangelist.Router.Site do
  require Erlangelist.Article
  use Erlangelist.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug Erlangelist.CookieCompliance
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
    get "/privacy_policy.html", SiteController, :privacy_policy
    post "/comments", ArticleController, :comments
    get "/article/:article_id", ArticleController, :article


    for article <- Erlangelist.Article.all do
      # old-style urls
      if article.legacy_url do
        get article.legacy_url, ArticleController,
          :article_from_old_path, private: %{article: article}
      end

      # redirect to blogspot for non-migrated articles
      if article.redirect do
        get article.link,
          OldPostController, :render, private: %{article: article}
      end
    end
  end

  scope "/", Erlangelist do
    get "/rss", RssController, :index
    get "/feeds/posts/default", RssController, :index
  end
end
