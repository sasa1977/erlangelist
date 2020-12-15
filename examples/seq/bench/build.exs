defmodule Helper do
  def build_list(size), do: build_list(0, size)

  defp build_list(size, size), do: []

  defp build_list(value, size), do: [value | build_list(value + 1, size)]

  def build_array(size), do: build_array(:array.new(), 0, size)

  defp build_array(array, index, index), do: array

  defp build_array(array, index, size),
    do: build_array(:array.set(index, index, array), index + 1, size)

  def build_map(size), do: build_map(%{}, 0, size)

  defp build_map(map, index, index), do: map

  defp build_map(map, index, size),
    do: build_map(Map.put(map, index, index), index + 1, size)
end

data =
  Bench.run(fn size ->
    [
      {"list", fn _ -> Helper.build_list(size) end},
      {"array", fn _ -> Helper.build_array(size) end},
      {"array from list", &:array.from_list/1, init: &Helper.build_list/1},
      {"map from list", &Map.new/1, init: fn size -> Enum.map(0..(size - 1), &{&1, &1}) end},
      {"map", fn _ -> Helper.build_map(size) end},
      {"tuple from list", &List.to_tuple/1, init: &Helper.build_list/1}
    ]
  end)

{"list", list_times} = Enum.find(data, &match?({"list", _values}, &1))

data =
  Enum.map(
    data,
    fn {key, values} ->
      if String.ends_with?(key, "from list") do
        values =
          values
          |> Enum.zip(list_times)
          |> Enum.map(fn {{size, value1}, {size, value2}} -> {size, value1 + value2} end)

        {key, values}
      else
        {key, values}
      end
    end
  )

Chart.build(
  data,
  commands: [
    [:set, :title, "incremental build"],
    [:set, :xlabel, "sequence size"],
    [:set, :format, :x, "%.0s%c"],
    [:set, :format, :y, "%.0s%cs"],
    [:set, :grid, :ytics]
  ]
)
