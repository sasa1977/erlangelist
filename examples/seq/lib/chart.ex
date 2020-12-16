defmodule Chart do
  def build(data, opts) do
    Application.put_env(:gnuplot, :timeout, {0, :ms})

    titles = Enum.map(data, fn {title, _} -> to_string(title) end)
    colors = ~w/black dark-green blue dark-khaki dark-violet gray40/
    pts = [4, 5, 6, 7, 12, 13]
    dts = [1, 2, 3, 4, 5, 6]

    plots =
      [titles, colors, pts, dts]
      |> Enum.zip()
      |> Enum.map(fn {title, color, pt, dt} ->
        [
          "-",
          :title,
          title,
          :smooth,
          :csplines,
          :with,
          :linespoints,
          :pn,
          5,
          :lc,
          :rgb,
          color,
          :dt,
          dt,
          :pt,
          pt,
          :ps,
          1.6
        ]
      end)
      |> Gnuplot.plots()

    Gnuplot.plot(
      Keyword.get(opts, :commands, []) ++ [[:set, :key, :left, :top], plots],
      Enum.map(
        data,
        fn {_title, points} -> Enum.map(points, &Tuple.to_list/1) end
      )
    )
  end
end
