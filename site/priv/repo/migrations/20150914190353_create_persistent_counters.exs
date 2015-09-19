defmodule Erlangelist.Repo.Migrations.CreatePersistentCounters do
  use Ecto.Migration

  def change do
    for table <- [
      :article_visits,
      :country_visits,
      :referer_host_visits,
      :referer_visits
    ] do
      create table(table) do
        add :key, :text, null: false
        add :value, :bigint, null: false
        add :created_at, :datetime,
          null: false,
          default: fragment("(now() at time zone 'utc')")
      end

      create index(table, [:key], unique: false)
      create index(table, [:created_at], unique: false)
    end
  end
end
