defmodule Erlangelist.Repo.Migrations.RemoveCounters do
  use Ecto.Migration

  def change do
    for table <- [
      :article_visits,
      :country_visits,
      :referer_host_visits,
      :referer_visits
    ] do
      drop table(table)
    end
  end
end
