defmodule Chart do
  def build(data, opts) do
    Application.put_env(:gnuplot, :timeout, {0, :ms})

    Gnuplot.plot(
      Keyword.get(opts, :commands, []) ++
        [
          [:set, :key, :left, :top],
          data
          |> Enum.map(fn {title, _} -> ["-", :title, to_string(title), :smooth, :csplines] end)
          |> Gnuplot.plots()
        ],
      Enum.map(
        data,
        fn {_title, points} -> Enum.map(points, &Tuple.to_list/1) end
      )
    )
  end
end
