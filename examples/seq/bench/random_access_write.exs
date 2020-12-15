defmodule Helper do
  def write_list(list, size), do: write_list(list, 0, size)

  defp write_list(list, index, index), do: list

  defp write_list(list, index, size),
    do: write_list(List.replace_at(list, index, :new), index + 1, size)

  def write_array(array, size), do: write_array(array, 0, size)

  defp write_array(array, index, index), do: array

  defp write_array(array, index, size),
    do: write_array(:array.set(index, :new, array), index + 1, size)

  def write_map(map, size), do: write_map(map, 0, size)

  defp write_map(map, index, index), do: map

  defp write_map(map, index, size),
    do: write_map(Map.put(map, index, :new), index + 1, size)

  def write_tuple(tuple, size), do: write_tuple(tuple, 0, size)

  defp write_tuple(tuple, index, index), do: tuple

  defp write_tuple(tuple, index, size),
    do: write_tuple(put_elem(tuple, index, :new), index + 1, size)

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
      list: fn _ -> Helper.write_list(list, size) end,
      array: fn _ -> Helper.write_array(array, size) end,
      map: fn _ -> Helper.write_map(map, size) end,
      tuple: fn _ -> Helper.write_tuple(tuple, size) end
    ]
    |> Enum.reject(fn
      {:list, _} when size > 10_000 -> true
      {:tuple, _} when size > 10_000 -> true
      _ -> false
    end)
  end)

Chart.build(
  data,
  commands: [
    [:set, :title, "random-access write"],
    [:set, :xlabel, "sequence size"],
    [:set, :grid, :xtics],
    [:set, :grid, :ytics],
    [:set, :format, :y, "%.0s%cs"],
    [:set, :format, :x, "%.0s%c"],
    [:set, :logscale, :x, 10],
    [:set, :logscale, :y, 10]
  ]
)
