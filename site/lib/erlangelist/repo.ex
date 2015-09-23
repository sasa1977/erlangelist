defmodule Erlangelist.Repo do
  require Logger
  use Ecto.Repo, otp_app: :erlangelist

  alias Erlangelist.OneOff
  alias Erlangelist.Metrics

  defoverridable start_link: 0, start_link: 1
  def start_link(opts \\ []) do
    result = super(opts)
    # Asynchronous migrations, so we don't crash if the database is down.
    # Allows us to start the site even if db is not available.
    OneOff.run(&migrate/0)
    result
  end

  defp migrate do
    try do
      Ecto.Migrator.run(
        __MODULE__,
        Application.app_dir(:erlangelist, "priv/repo/migrations"),
        :up,
        all: true
      )
      Logger.info("database migrated")
    catch type, error ->
      Logger.error("Error migrating the database: #{inspect {type, error}}")
      :timer.sleep(:timer.seconds(5))
      migrate
    end
  end

  def log(log_entry) do
    queue_time = (log_entry.queue_time || 0) / 1000
    total_time = log_entry.query_time / 1000 + queue_time
    OneOff.run(fn ->
      Metrics.sample_histogram([:site, :db, :queries, :queue_time], queue_time)
      Metrics.sample_histogram([:site, :db, :queries, :total_time], total_time)
      Metrics.inc_spiral([:site, :db, :queries, :count])
    end)

    super(log_entry)
  end
end
