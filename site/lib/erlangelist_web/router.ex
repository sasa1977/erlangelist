defmodule ErlangelistWeb.Router do
  use ErlangelistWeb, :router

  pipeline :browser do
    plug(ErlangelistWeb.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com")
    plug(:accepts, ["html"])
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(ErlangelistWeb.MovePermanently, from: "theerlangelist.com", to: "www.theerlangelist.com")
    plug(:accepts, ["json"])
  end

  scope "/", ErlangelistWeb do
    # rss feed
    get("/rss", RssController, :index)
    get("/feeds/posts/*any", RssController, :index)
  end

  scope "/", ErlangelistWeb do
    # Use the default browser stack
    pipe_through(:browser)

    # articles
    get("/", ArticleController, :most_recent)
    get("/article/:article_id", ArticleController, :article)

    get("/privacy_policy.html", SiteController, :privacy_policy)

    get("/*rest", ArticleController, :not_found)
  end
end
