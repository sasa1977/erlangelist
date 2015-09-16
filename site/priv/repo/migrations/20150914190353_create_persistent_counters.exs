defmodule Erlangelist.Repo.Migrations.CreatePersistentCounters do
  use Ecto.Migration

  def change do
    create table(:persistent_counters) do
      add :category, :text, null: false
      add :name, :text, null: false
      add :value, :bigint, null: false
      add :created_at, :datetime,
        null: false,
        default: fragment("(now() at time zone 'utc')")
    end

    create index(:persistent_counters, [:category, :name], unique: false)
    create index(:persistent_counters, [:created_at], unique: false)
  end
end
