defmodule Erlangelist.Router.Admin do
  use Erlangelist.Web, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/", Erlangelist do
    pipe_through :browser # Use the default browser stack

    get "/", AdminController, :index
  end
end
