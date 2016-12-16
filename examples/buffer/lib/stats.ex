defmodule Stats do
  def percentiles(series, percentiles) do
    indexed =
      series
      |> Enum.sort()
      |> Stream.with_index()
      |> Enum.map(fn({value, index}) -> {index, value} end)
      |> Enum.into(%{})

    percentiles
    |> Enum.map(&round(Map.size(indexed) * &1))
    |> Enum.map(&min(&1, Map.size(indexed) - 1))
    |> Enum.map(&Map.fetch!(indexed, &1))
  end
end
