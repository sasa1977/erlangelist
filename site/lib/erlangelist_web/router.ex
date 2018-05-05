defmodule ErlangelistWeb.Router do
  use ErlangelistWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", ErlangelistWeb do
    # Use the default browser stack
    pipe_through(:browser)

    # articles
    get("/", ArticleController, :most_recent)
    get("/article/:article_id", ArticleController, :article)

    get("/privacy_policy.html", SiteController, :privacy_policy)

    # rss feed
    get("/rss", RssController, :index)
    get("/feeds/posts/*any", RssController, :index)

    for article <- Erlangelist.Article.all() do
      # old-style urls
      if article.legacy_url do
        get(article.legacy_url, ArticleController, :article_from_old_path, private: %{article: article})
      end

      # redirect to blogspot for non-migrated articles
      if article.redirect do
        get(article.link, OldPostController, :render, private: %{article: article})
      end
    end

    get("/*rest", ArticleController, :not_found)
  end
end
