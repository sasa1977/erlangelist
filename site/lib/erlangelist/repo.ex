defmodule Erlangelist.Repo do
  require Logger
  use Ecto.Repo, otp_app: :erlangelist

  alias Erlangelist.Metrics

  def start_migration do
    # Asynchronous migrations, so we don't crash if the database is down.
    # Allows us to start the site even if db is not available.
    Task.start_link(&migrate/0)
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
      Logger.error(inspect({type, error, System.stacktrace}))
      :timer.sleep(:timer.seconds(5))
      migrate
    end
  end

  defoverridable __log__: 1
  def __log__(log_entry) do
    queue_time = (log_entry.queue_time || 0) / 1000
    total_time = log_entry.query_time / 1000 + queue_time

    Metrics.sample_histogram([:site, :db, :queries, :queue_time], queue_time)
    Metrics.sample_histogram([:site, :db, :queries, :total_time], total_time)
    Metrics.inc_spiral([:site, :db, :queries, :count])

    super(log_entry)
  end
end
