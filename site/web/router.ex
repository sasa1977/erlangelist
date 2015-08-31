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

    get "/", ArticleController, :most_recent
    get "/article/:article_id", ArticleController, :article

    for {_article_id, meta} <- Erlangelist.Article.all do
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
