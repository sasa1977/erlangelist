defmodule Erlangelist.PersistentCounterServer do
  require Logger
  use Workex

  alias Erlangelist.Repo

  def inc(model, data) do
    case Supervisor.start_child(__MODULE__, [model]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
    |> Workex.push(data)
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

  def start_link(model) do
    Workex.start_link(
      __MODULE__,
      model,
      [aggregate: Erlangelist.Workex.Counts.new],
      [name: {:via, :gproc, {:n, :l, {:updater, model}}}]
    )
  end


  @inactivity_timeout :timer.seconds(30)

  def init(state), do: {:ok, state, @inactivity_timeout}

  def handle(data, model) do
    # Don't really want to crash here, because it might cause too many
    # restarts and ultimately overload the system. This is a non-critical work,
    # so just log error and resume as normal.
    try do
      results = db_inc(model, Enum.to_list(data))
      for {:error, error} <- results do
        Logger.error("Database error: #{inspect error}")
      end
    catch
      type, error ->
        Logger.error("#{inspect type}: #{inspect error}")
    end

    # Some breathing space, so we don't update too often.
    :timer.sleep(:timer.seconds(5))

    {:ok, model, @inactivity_timeout}
  end

  def handle_message(:timeout, state), do: {:stop, :normal, state}
  def handle_message(_, state), do: {:ok, state, @inactivity_timeout}

  defp db_inc(model, data) do
    table_name = model.__schema__(:source)

    for {key, inc} <- data do
      Ecto.Adapters.SQL.query(
        Repo,
        ~s/
          insert into #{table_name} (key, value) (
            select $1, inc + coalesce(previous.value, 0)
            from
              (select #{inc} inc) increment
              left join (
                select value
                from #{table_name}
                where key=$1
                order by id desc
                limit 1
              ) previous on true
          )
        /
        |> String.replace(~r(\s+), " "),
        [key]
      )
    end
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


defmodule Erlangelist.Workex.Counts do
  @moduledoc """
  Aggregates messages in the queue like fashion. The aggregated value will be a list
  that preserves the order of messages.
  """
  defstruct counts: %{}

  def new, do: %__MODULE__{}

  @doc false
  def add(struct, [_|_] = pairs) do
    {:ok, Enum.reduce(pairs, struct, &do_add(&2, &1))}
  end
  def add(struct, []), do: struct
  def add(struct, key_or_pair), do: add(struct, [key_or_pair])


  defp do_add(%__MODULE__{counts: counts} = struct, {key, by}) do
    %__MODULE__{struct | counts: Map.update(counts, key, by, &(&1 + by))}
  end

  defp do_add(struct, key), do: do_add(struct, {key, 1})


  @doc false
  def value(%__MODULE__{counts: counts}), do: {counts, new}

  @doc false
  def size(%__MODULE__{counts: counts}), do: Map.size(counts)

  defimpl Workex.Aggregate do
    defdelegate add(aggregate, message), to: Erlangelist.Workex.Counts
    defdelegate value(aggregate), to: Erlangelist.Workex.Counts
    defdelegate size(aggregate), to: Erlangelist.Workex.Counts
    def remove_oldest(_), do: raise("not implemented")
  end
end
