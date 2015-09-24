defmodule Erlangelist.PersistentCounterServer do
  require Logger
  use Workex

  alias Erlangelist.Analytics

  def inc(model, data) do
    case Supervisor.start_child(__MODULE__, [model]) do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
    |> Workex.push(data)
  end

  def start_sup do
    import Supervisor.Spec, warn: false

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
      results = Analytics.inc(model, Enum.to_list(data))
      for {:error, error} <- results do
        Logger.error("Database error: #{inspect error}")
      end
    catch
      type, error ->
        Logger.error(inspect({type, error, System.stacktrace}))
    end

    # Some breathing space, so we don't update too often.
    :timer.sleep(:timer.seconds(10))

    {:ok, model, @inactivity_timeout}
  end

  def handle_message(:timeout, state), do: {:stop, :normal, state}
  def handle_message(_, state), do: {:ok, state, @inactivity_timeout}
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
