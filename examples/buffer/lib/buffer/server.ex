defmodule Buffer.Server do
  use GenServer

  def start_link(buffer_mod, max_size), do:
    GenServer.start_link(__MODULE__, {buffer_mod, max_size})

  def push(buffer_pid, item), do:
    GenServer.call(buffer_pid, {:push, item})

  def pull(buffer_pid), do:
    GenServer.call(buffer_pid, :pull)

  def init({buffer_mod, max_size}), do:
    {:ok, %{buffer_mod: buffer_mod, buffer: buffer_mod.new(max_size)}}

  def handle_call({:push, item}, _from, state), do:
    {:reply, :ok, %{state | buffer: state.buffer_mod.push(state.buffer, item)}}

  def handle_call(:pull, _from, state) do
    case state.buffer_mod.pull(state.buffer) do
      {:ok, {value, buffer}} -> {:reply, {:ok, value}, %{state | buffer: buffer}}
      {:error, _} = error -> {:reply, error, state}
    end
  end
end
