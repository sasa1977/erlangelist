defmodule Erlangelist.PersistentCounterServer do
  require Logger
  use Workex
  import Ecto.Query, only: [from: 2]

  alias Erlangelist.Repo

  def inc(model, key, by \\ 1) do
    case Supervisor.start_child(__MODULE__, [model, key]) do
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

  def start_link(model, key) do
    Workex.start_link(
      __MODULE__,
      {model, key},
      [aggregate: Erlangelist.Workex.Counter.new],
      [name: {:via, :gproc, {:n, :l, {model, key}}}]
    )
  end


  @inactivity_timeout :timer.seconds(30)

  def init(state), do: {:ok, state, @inactivity_timeout}

  def handle(by, {model, key} = state) do
    # Don't really want to crash here, because it might cause too many
    # restarts and ultimately overload the system. This is a non-critical work,
    # so just log error and resume as normal.
    try do
      {:ok, _} = db_inc(model, key, by)
    catch
      type, error ->
        Logger.error("#{inspect type}: #{inspect error}")
    end

    # Some breathing space, so we don't update too often.
    :timer.sleep(:timer.seconds(1))

    {:ok, state, @inactivity_timeout}
  end

  def handle_message(:timeout, state), do: {:stop, :normal, state}
  def handle_message(_, state), do: {:ok, state, @inactivity_timeout}

  defp db_inc(model, key, by) do
    latest_count =
      Repo.one(
        from visit in model,
          select: visit.value,
          where: visit.key == ^key,
          order_by: [desc: :id],
          limit: 1
      ) || 0

    model.new(key, latest_count + by)
    |> Repo.insert
  end

  def compact do
    {:ok, %{rows: inherited_tables}} =
      Ecto.Adapters.SQL.query(
        Repo,
        ~s{
          select cast(c.relname as text)
          from pg_inherits
          join pg_class AS c on (inhrelid=c.oid)
          join pg_class as p on (inhparent=p.oid)
          where p.relname = 'persistent_counters'
        },
        []
      )

    for [table_name] <- inherited_tables do
      {:ok, %{num_rows: num_rows}} = Ecto.Adapters.SQL.query(
        Repo,
        ~s{
          delete from #{table_name}
          using (
            select key, date(created_at) created_at_date, max(value) max_value
            from #{table_name}
            where date(created_at) < date(now())
            group by key, date(created_at)
          ) newest
          where
            #{table_name}.key=newest.key
            and date(#{table_name}.created_at)=newest.created_at_date
            and #{table_name}.value < newest.max_value
        },
        []
      )

      if num_rows > 0 do
        Logger.info("#{table_name} compacted, deleted #{num_rows} rows")
      end
    end
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
