defmodule Erlangelist.Repo.Migrations.CreatePersistentCounters do
  use Ecto.Migration

  def change do
    create table(:persistent_counters) do
      add :name, :text, null: false
      add :value, :bigint, null: false
      add :created_at, :datetime,
        null: false,
        default: fragment("(now() at time zone 'utc')")
    end

    for table <- [:article_visits, :country_visits] do
      create table(table, options: "inherits(persistent_counters)")
      create index(table, [:name], unique: false)
      create index(table, [:created_at], unique: false)
    end
  end
end
