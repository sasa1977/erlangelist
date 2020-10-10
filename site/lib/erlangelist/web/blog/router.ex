defmodule Erlangelist.Web.Blog.Router do
  use Phoenix.Router
  import Phoenix.Controller

  pipeline :browser do
    plug :accepts, ["html"]
    plug :put_secure_browser_headers
  end

  scope "/", Erlangelist.Web.Blog do
    # rss feed
    get "/rss", Controller, :rss
    get "/feeds/posts/*any", Controller, :rss
  end

  scope "/", Erlangelist.Web.Blog do
    # Use the default browser stack
    pipe_through :browser

    # articles
    get "/", Controller, :most_recent_article
    get "/article/:article_id", Controller, :article
    get "/privacy_policy.html", Controller, :privacy_policy
    get "/*rest", Controller, :not_found
  end
end
