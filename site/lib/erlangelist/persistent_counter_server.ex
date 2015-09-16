defmodule Erlangelist.PersistentCounterServer do
  require Logger
  use Workex
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo
  alias Erlangelist.Model.PersistentCounter

  def inc(category, name, by \\ 1) do
    case Supervisor.start_child(__MODULE__, [category, name]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
    |> Workex.push(by)
  end

  def start_sup do
    import Supervisor.Spec, warn: false

    Ecto.Migrator.run(
      Repo,
      Application.app_dir(:erlangelist, "priv/repo/migrations"),
      :up,
      all: true
    )

    Supervisor.start_link(
      [worker(__MODULE__, [], restart: :temporary)],
      name: __MODULE__,
      strategy: :simple_one_for_one
    )
  end

  def start_link(category, name) do
    Workex.start_link(
      __MODULE__,
      {category, name},
      [aggregate: Erlangelist.Workex.Counter.new],
      [name: {:via, :gproc, {:n, :l, {category, name}}}]
    )
  end

  def init(state), do: {:ok, state}

  def handle(by, {category, name} = state) do
    # Don't really want to crash here, because it might cause too many
    # restarts and ultimately overload the system. This is a non-critical work,
    # so just log error and resume as normal.
    try do
      {:ok, _} = db_inc(category, name, by)
    catch
      type, error ->
        Logger.error("#{inspect type}: #{inspect error}")
    end

    # Some breathing space, so we don't update too often.
    :timer.sleep(:timer.seconds(1))

    {:ok, state}
  end

  defp db_inc(category, name, by) do
    latest_count =
      Repo.one(
        from pc in PersistentCounter,
          select: pc.value,
          where: pc.category == ^category and pc.name == ^name,
          order_by: [desc: :id],
          limit: 1
      ) || 0

    PersistentCounter.new(category, name, latest_count + by)
    |> Repo.insert
  end

  def compact do
    {:ok, %{num_rows: num_rows}} = Ecto.Adapters.SQL.query(
      Repo,
      ~s{
        delete from persistent_counters
        using (
          select category, name, date(created_at) created_at_date, max(id) id
          from persistent_counters
          where date(created_at) < date(now())
          group by category, name, date(created_at)
        ) newest
        where
          persistent_counters.category=newest.category
          and persistent_counters.name=newest.name
          and date(persistent_counters.created_at)=newest.created_at_date
          and persistent_counters.id < newest.id
      },
      []
    )

    Logger.info("Counters compacted, deleted #{num_rows} rows")
  end
end


defmodule Erlangelist.Workex.Counter do
  @moduledoc """
  Aggregates messages in the queue like fashion. The aggregated value will be a list
  that preserves the order of messages.
  """
  defstruct count: 0

  def new, do: %__MODULE__{}

  @doc false
  def add(%__MODULE__{count: count} = counter, by) do
    {:ok, %__MODULE__{counter | count: count + by}}
  end

  @doc false
  def value(%__MODULE__{count: count}), do: {count, new}

  @doc false
  def size(%__MODULE__{count: count}), do: count

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Erlangelist.Workex.Counter
    defdelegate value(aggregate), to: Erlangelist.Workex.Counter
    defdelegate size(aggregate), to: Erlangelist.Workex.Counter
    def remove_oldest(_), do: raise("not implemented")
  end
end
