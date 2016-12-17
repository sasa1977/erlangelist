defmodule Mix.Tasks.Buffer.Bench do
  use Mix.Task

  alias Buffer.Server

  def run(args) do
    {parsed, []} =
      OptionParser.parse!(args,
        switches: [
          buffer_mod: :string,
          buffer_size: :integer,
          operations: :integer,
          pushes: :integer,
          pulls: :integer
        ],
        aliases: [m: :buffer_mod]
      )

    options = Keyword.merge(
      [
        buffer_mod: "Buffer.Ets",
        buffer_size: 200_000,
        operations: 2_000_000,
        pushes: 15,
        pulls: 5
      ],
      parsed
    )

    operations = Keyword.fetch!(options, :operations)
    buffer_size = Keyword.fetch!(options, :buffer_size)
    pushes = Keyword.fetch!(options, :pushes)
    pulls = Keyword.fetch!(options, :pulls)
    buffer_mod = Module.concat([Keyword.fetch!(options, :buffer_mod)])

    {:ok, buffer_pid} = Server.start_link(Module.concat([buffer_mod]), buffer_size)


    num_cycles = div(operations, (pushes + pulls))

    IO.puts "\nWarming up..."
    Enum.each(1..buffer_size, &Server.push(buffer_pid, new_message(&1)))
    Enum.each(1..buffer_size, fn(_) -> Server.pull(buffer_pid) end)
    Enum.each(1..buffer_size, &Server.push(buffer_pid, new_message(&1)))

    IO.puts "Benching #{buffer_mod} using #{pulls} pulls and #{pushes} pushes per cycle..."
    {:ok, tracer_pid} = BufferTracer.start_link(buffer_pid)

    Enum.each(1..num_cycles, fn(cycle) ->
      Enum.each(1..pulls, fn(_) -> Server.pull(buffer_pid) end)
      Enum.each(1..pushes, &Server.push(buffer_pid, new_message((cycle - 1) * pushes + &1)))
      IO.write("\r#{div(100 * cycle, num_cycles)} %")
    end)

    stats = BufferTracer.stats(tracer_pid)
    BufferTracer.stop(tracer_pid)

    IO.puts "\r\n"
    print_percentiles(stats)

    IO.puts "Buffer process memory: #{round((Process.info(buffer_pid) |> Keyword.fetch!(:total_heap_size)) * :erlang.system_info(:wordsize) / 1000)} KB"
    IO.puts "Total memory used: #{round((:erlang.memory() |> Keyword.fetch!(:total)) / 1_000_000)} MB\n"
  end

  defp new_message(index), do: <<index::1024-unit(8)>>

  defp print_percentiles(stats) do
    for {key, data} <- stats do
      IO.puts("#{key} (#{data.count} times, average: #{data.avg} us)")

      data.percentiles
      |> Enum.each(fn({label, time}) ->  IO.puts "  #{label}%: #{time} us" end)

      IO.puts "  Longest 10 (us): #{Enum.join(data.worst_10, " ")}\n"
    end
  end
end
