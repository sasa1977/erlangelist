defmodule Buffer.Ets do
  defstruct [:max_size, :size, :push_index, :pull_index, :ets]

  def new(max_size) do
    ets = :ets.new(:buffer, [read_concurrency: false, write_concurrency: false])

    Enum.each(0..(max_size - 1), &:ets.insert(ets, {&1, nil}))

    %__MODULE__{
      max_size: max_size,
      size: 0,
      push_index: 0,
      pull_index: 0,
      ets: ets
    }
  end

  def size(buffer), do: buffer.size

  def push(buffer, msg) do
    :ets.update_element(buffer.ets, buffer.push_index, {2, msg})

    next_push_index = rem(buffer.push_index + 1, buffer.max_size)
    next_pull_index =
      if buffer.size == buffer.max_size,
        do: next_push_index,
        else: buffer.pull_index

    %__MODULE__{buffer |
      size: min(buffer.size + 1, buffer.max_size),
      push_index: next_push_index,
      pull_index: next_pull_index
    }
  end

  def pull(%__MODULE__{size: 0}), do: {:error, :empty}
  def pull(%__MODULE__{pull_index: pull_index} = buffer) do
    {:ok, {
      :ets.lookup_element(buffer.ets, pull_index, 2),
      %__MODULE__{buffer |
        size: buffer.size - 1,
        pull_index: rem(pull_index + 1, buffer.max_size)
      }
    }}
  end
end
