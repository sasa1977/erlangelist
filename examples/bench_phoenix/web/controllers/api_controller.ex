defmodule BenchPhoenix.ApiController do
  use BenchPhoenix.Web, :controller

  def sum(conn, %{"a" => a, "b" => b}) do
    json(conn, %{result: a + b})
  end
end
