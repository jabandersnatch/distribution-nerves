defmodule Count do

  def read(file) do
    {:ok, string} = File.read("files/#{file}")
    string
  end

  def	processing_fun(list,_)	do
    list
    |> Enum.filter(fn element -> Regex.match?(~r/\A\d+\z|\A[a-zA-Z]+\z|\A[a-zA-Z]+'[a-zA-Z]+\z/, element) end)
    |> Enum.reduce(%{}, fn palabra, conteo -> Map.update(conteo, palabra, 1, &(&1 + 1)) end)
  end

  def partition_fun(string,n) do
    string
    |> String.downcase()
    |>(fn cadena -> Regex.replace(~r/[^a-zA-Z0-9'\s]/, cadena, "") end).()
    words = String.split(string, ~r/\s+/, trim: true)

    total_words = length(words)
    words_per_list = div(total_words, n)
    leftover_words = rem(total_words, n)

    lists = distribute_words(words, words_per_list, leftover_words)
    lists
  end

  defp distribute_words(words, words_per_list, leftover_words) do
    Enum.chunk_every(words, words_per_list + (if leftover_words > 0, do: 1, else: 0))
  end

  def merge_fun(dictionaries) do
    Enum.reduce(dictionaries, %{}, fn(dict, acc) ->
      Enum.reduce(dict, acc, fn({key, value}, acc_dict) ->
        Map.update(acc_dict, key, value, &(&1 + value))
      end)
    end)

  end

  def persistence_fun(dict) do
    IO.inspect(dict)
  end

  def count do
    {elapsed_time, result} = :timer.tc(fn -> ParallelServer.execute_distributed_task(Count.read("string.txt"),(&Count.partition_fun/2),(&Count.merge_fun/1),(&Count.persistence_fun/1),(&Count.processing_fun/2)) end)
    IO.puts("El tiempo total de ejecución es #{elapsed_time/1000000} segundos.")
    result
   end
end
