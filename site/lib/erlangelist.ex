defmodule Erlangelist do
  def app_env!(name) do
    {:ok, value} = Application.fetch_env(:erlangelist, name)
    value
  end
end
