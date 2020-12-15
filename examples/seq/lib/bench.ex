defmodule Bench do
  def run(max_exp \\ 6, fun) do
    :erlang.system_flag(:schedulers_online, 1)

    for {exp, iterations_exp} <-
          Enum.zip(
            0..max_exp,
            5..1 |> Stream.concat(Stream.repeatedly(fn -> 1 end)) |> Enum.take(max_exp + 1)
          ),
        scale = trunc(:math.pow(10, exp)),
        iterations = trunc(:math.pow(10, iterations_exp)),
        IO.inspect(scale),
        factor <- if(exp == max_exp, do: [1], else: 1..9) do
      size = scale * factor

      Enum.map(
        fun.(size),
        fn
          {label, fun} -> {label, {size, measure(size, iterations, fun, [])}}
          {label, fun, opts} -> {label, {size, measure(size, iterations, fun, opts)}}
        end
      )
    end
    |> List.flatten()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp measure(size, iterations, fun, opts) do
    caller = self()

    spawn(fn ->
      init = Keyword.get(opts, :init, fn _ -> nil end)

      time =
        for _ <- 1..iterations do
          arg = init.(size)
          start = System.monotonic_time(:nanosecond)
          fun.(arg)
          System.monotonic_time(:nanosecond) - start
        end
        |> Enum.sum()
        |> Kernel./(iterations * 1_000_000_000)

      send(caller, {:time, time})
    end)

    receive do
      {:time, time} -> time
    end
  end
end
