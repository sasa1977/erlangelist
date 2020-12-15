defmodule Helper do
  def read_list(list, size), do: read_list(list, 0, size)

  defp read_list(list, index, index), do: list

  defp read_list(list, index, size) do
    Enum.at(list, index)
    read_list(list, index + 1, size)
  end

  def read_array(array, size), do: read_array(array, 0, size)

  defp read_array(array, index, index), do: array

  defp read_array(array, index, size) do
    :array.get(index, array)
    read_array(array, index + 1, size)
  end

  def read_map(map, size), do: read_map(map, 0, size)

  defp read_map(map, index, index), do: map

  defp read_map(map, index, size) do
    _ = Map.fetch!(map, index)
    read_map(map, index + 1, size)
  end

  def read_tuple(tuple, size), do: read_tuple(tuple, 0, size)

  defp read_tuple(tuple, index, index), do: tuple

  defp read_tuple(tuple, index, size) do
    _ = elem(tuple, index)
    read_tuple(tuple, index + 1, size)
  end

  def measure(iterations, fun) do
    caller = self()

    spawn(fn ->
      start = System.monotonic_time(:nanosecond)

      for _ <- 1..iterations do
        fun.()
      end

      time = (System.monotonic_time(:nanosecond) - start) |> Kernel./(iterations)

      send(caller, {:time, time})
    end)

    receive do
      {:time, time} -> time
    end
  end
end

data =
  Bench.run(fn size ->
    list = Enum.to_list(0..(size - 1))
    array = :array.from_list(list)
    map = list |> Enum.with_index() |> Enum.into(%{}, fn {val, index} -> {index, val} end)
    tuple = List.to_tuple(list)

    [
      list: fn _ -> Helper.read_list(list, size) end,
      array: fn _ -> Helper.read_array(array, size) end,
      map: fn _ -> Helper.read_map(map, size) end,
      tuple: fn _ -> Helper.read_tuple(tuple, size) end
    ]
    |> Enum.reject(fn
      {:list, _} when size > 10_000 -> true
      _ -> false
    end)
  end)

Chart.build(
  data,
  commands: [
    [:set, :title, "random-access read"],
    [:set, :xlabel, "sequence size"],
    [:set, :grid, :xtics],
    [:set, :grid, :ytics],
    [:set, :format, :x, "%.0s%c"],
    [:set, :format, :y, "%.0s%cs"],
    [:set, :logscale, :x, 10],
    [:set, :logscale, :y, 10]
  ]
)
