defmodule WordCounter do
  def load_from_files(file_names) do
    file_names
    |> Stream.map(fn name -> Task.async(fn -> load_file(name) end) end)
    |> Enum.flat_map(&Task.await/1)
  end

  defp load_file(name) do
    File.stream!(name, [], :line)
    |> Enum.map(&String.trim/1)
  end

  def into_big_list(file_names) do
    file_names
    |> load_from_files()
    |> Enum.flat_map(&String.split(&1, ~r/\W+/))
    |> Stream.map(fn word ->
      Task.async(fn -> String.replace(word, ~r/[^0-9A-Za-z'\- ]/, "") |> String.downcase() end)
    end)
    |> Enum.map(&Task.await/1)
  end

  def list_count(list) do
    list |> Enum.reduce(%{}, fn word, map -> count(word, map) end)
  end

  def parallel_count(file_names) do
    list = into_big_list(file_names)

    Enum.chunk_every(list, div(length(list), System.schedulers_online()))
    |> Enum.map(fn list_i -> Task.async(fn -> list_count(list_i) end) end)
    |> Enum.map(&Task.await/1)
    |> reduce_maps()
  end

  defp merge_maps([map1, map2]) do
    Map.merge(map1, map2, fn _k, v1, v2 -> v1 + v2 end)
  end

  defp merge_maps([map]) do
    map
  end

  defp reduce_maps([map]) do
    map
  end

  defp reduce_maps(list_of_maps) do
    Enum.chunk_every(list_of_maps, 2)
    |> Enum.map(fn pair -> Task.async(fn -> merge_maps(pair) end) end)
    |> Enum.map(&Task.await/1)
    |> reduce_maps()
  end

  defp count(word, map) do
    Map.update(map, word, 1, &(&1 + 1))
  end

  def main do
    Enum.map(1..5, &"priv/list#{&1}.txt")
    |> parallel_count()
    # |> IO.inspect()

    # |> Enum.each(&IO.inspect/1)
  end

  def runBench(func) do
    func |> :timer.tc |> elem(0) |> Kernel./(1_000_000) |> IO.inspect()
  end
end
