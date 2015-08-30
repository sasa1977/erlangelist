defmodule Erlangelist.Router do
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

    get "/", PageController, :index
    get "/why_elixir", ArticleController, :post
    get "/2012/12/yet-another-introduction-to-erlang.html", OldPostController, :render
  end

  # Other scopes may use custom stacks.
  # scope "/api", Erlangelist do
  #   pipe_through :api
  # end
end
