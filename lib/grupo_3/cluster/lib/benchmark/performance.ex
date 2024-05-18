defmodule Benchmark.Performance do
  @time_nano :nanosecond
  @time_mili :millisecond
  def execute_nano(module, fun, args) do
    start_time = :os.system_time(@time_nano)
    Kernel.apply(module, fun, args)
    :os.system_time(@time_nano) - start_time
  end

  def execute_mili(module, fun, args) do
    start_time = :os.system_time(@time_mili)
    _ = Kernel.apply(module, fun, args)
    :os.system_time(@time_mili) - start_time
  end

  @doc """
  Use example
  Benchmark.Performance.average_mili(Exercises.Task1, :count, [String.duplicate(Exercises.Texto.get_text(), 2), 1])
  """
  def average_mili(module, fun, args) do
    IO.puts("START TEST\n")
    tries = 10

    total_time =
      Enum.reduce(1..tries, 0, fn attemp, acc ->
        IO.puts("Attemp number: #{attemp}")
        execution_time = execute_mili(module, fun, args)
        IO.puts("Time of execution in miliseconds: #{execution_time}\n")
        acc + execution_time
      end)

    IO.puts("\nRESULTS:")
    IO.puts("Number of attemps: #{tries}")
    average_time = total_time / tries
    IO.puts("Average time of execution: #{average_time}")
    {:ok}
  end

  @doc """
  Use example
  Benchmark.Performance.average_mili(Exercises.Task1, :count, [String.duplicate(Exercises.Texto.get_text(), 2), 1])
  """
  def average_nano(module, fun, args) do
    IO.puts("START TEST\n")
    tries = 10

    total_time =
      Enum.reduce(1..tries, 0, fn attemp, acc ->
        IO.puts("Attemp number: #{attemp}")
        execution_time = execute_nano(module, fun, args)
        IO.puts("Time of execution in miliseconds: #{execution_time}\n")
        acc + execution_time
      end)

    IO.puts("\nRESULTS:")
    IO.puts("Number of attemps: #{tries}")
    average_time = total_time / tries
    IO.puts("Average time of execution: #{average_time}")
    {:ok}
  end
end
