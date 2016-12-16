defmodule Buffer.Queue do
  defstruct [:max_size, :size, :queue]

  def new(max_size) when max_size > 0, do:
    %__MODULE__{max_size: max_size, size: 0, queue: :queue.new()}

  def size(buffer), do: buffer.size

  def push(%__MODULE__{max_size: max_size, size: max_size} = buffer, item) do
    {:ok, {_, buffer}} = pull(buffer)
    push(buffer, item)
  end
  def push(buffer, item), do:
    %__MODULE__{buffer | size: buffer.size + 1, queue: :queue.in(item, buffer.queue)}

  def pull(buffer) do
    case :queue.out(buffer.queue) do
      {:empty, _} -> {:error, :empty}
      {{:value, item}, queue} ->
        {:ok, {item, %__MODULE__{buffer | size: buffer.size - 1, queue: queue}}}
    end
  end
end
