defmodule Erlangelist do
  def app_env!(name) do
    {:ok, value} = Application.fetch_env(:erlangelist, name)
    value
  end

  def priv_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv") | parts])
  def priv_path(name), do: priv_path([name])

  def db_path(parts) when is_list(parts), do: Path.join([Application.app_dir(:erlangelist, "priv"), "db" | parts])
  def db_path(name), do: db_path([name])
end
