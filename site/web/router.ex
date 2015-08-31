defmodule Erlangelist.Router do
  require Erlangelist.Article
  use Erlangelist.Web, :router

  pipeline :browser do
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

    get "/", ArticleController, :last
    get "/article/:article_id", ArticleController, :post

    for {_article_id, meta} <- Erlangelist.Article.all_articles("#{File.cwd!}/priv") do
      if path = meta[:redirect] do
        get String.replace(path, "http://theerlangelist.blogspot.com",""), OldPostController, :render
      end
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", Erlangelist do
  #   pipe_through :api
  # end
end
