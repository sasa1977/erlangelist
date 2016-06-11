defmodule BenchPhoenix.Router do
  use BenchPhoenix.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BenchPhoenix do
    pipe_through :api

    post "/sum", ApiController, :sum
  end
end
