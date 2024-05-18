defmodule Exercises.Task1 do

  def count(string, split_list \\ 1) when is_bitstring(string) do
    words_list =
      string
      |> String.replace(~r"[?:_!@#$%^&*:|,./]", "")
      |> String.replace("\n", " ")
      |> String.downcase()
      |> String.replace("\t", " ")
      # |> String.duplicate(700)
      |> String.split(" ")
      |> Enum.filter(fn x -> x != "" end)

    IO.puts("Number of words #{Integer.to_string(Enum.count(words_list))}")
    # count_l(list_of_words) #only one list

    # Divide the list int two and sub list the same way n times
    # split_in_half_parts(words_list, 0)

    # Split in equals parts
    IO.inspect(split_in_equals_parts(words_list, split_list))
  end

  @spec split_in_equals_parts(any()) :: any()
  def split_in_equals_parts(words_list, parts_to_divide \\ 1) do
    parts_to_divide = if parts_to_divide < 1, do: 1, else: parts_to_divide

    divide_in = Integer.floor_div(Enum.count(words_list), parts_to_divide)

    Enum.chunk_every(words_list, divide_in)
    |> Enum.map(fn part_of_list ->
      Task.async(fn ->
        Cluster.TaskCall.run_sync_auto_detect(__MODULE__, :count_l, [part_of_list])
      end)
    end)
    |> Task.await_many(:infinity)
    |> Enum.reduce(Map.new(), fn feature_map, pivot_branch ->
      Map.merge(feature_map, pivot_branch, fn _k, v1, v2 ->
        v1 + v2
      end)
    end)
  end

  def split_in_half_parts(words_list, times \\ 0) do
    if times == 0 do
      count_l(words_list)
    else
      list_of_list =
        Enum.split(words_list, Integer.floor_div(Enum.count(words_list), 2))

      Enum.map(Tuple.to_list(list_of_list), fn list_splited ->
        Task.async(fn -> split_in_half_parts(list_splited, times - 1) end)
      end)
      |> Task.await_many(:infinity)

      Enum.reduce(list_of_list, Map.new(), fn feature_map, pivot_branch ->
        Map.merge(feature_map, pivot_branch, fn _k, v1, v2 ->
          v1 + v2
        end)
      end)
    end
  end

  def count_l(list_of_words) when is_list(list_of_words) do
    Enum.reduce(list_of_words, Map.new(), fn word, words_map ->
      if Map.get(words_map, word) == nil do
        Map.put(words_map, word, 1)
      else
        Map.put(words_map, word, Map.get(words_map, word) + 1)
      end
    end)
  end

  def count_l(index) when is_number(index) do
    list_of_words = Cluster.Variable.get_value() |> Enum.at(index)
    IO.puts("past from here #{index}")
    IO.inspect(list_of_words)

    Enum.reduce(list_of_words, Map.new(), fn word, words_map ->
      if Map.get(words_map, word) == nil do
        Map.put(words_map, word, 1)
      else
        Map.put(words_map, word, Map.get(words_map, word) + 1)
      end
    end)
  end

  def test_t3 do
    total = 10
    map_result = count("This\tis\na test Test 1230 They're They it's the it they're")
    lowercase_map = Map.new(map_result, fn {key, value} -> {String.downcase(key), value} end)

    valid_number =
      []
      |> Kernel.++([lowercase_map["this"] == 1])
      |> Kernel.++([lowercase_map["1230"] == 1])
      |> Kernel.++([lowercase_map["test"] == 2])
      |> Kernel.++([lowercase_map["is"] == 1])
      |> Kernel.++([lowercase_map["they"] == 1])
      |> Kernel.++([lowercase_map["a"] == 1])
      |> Kernel.++([lowercase_map["the"] == 1])
      |> Kernel.++([lowercase_map["it"] == 1])
      |> Kernel.++([lowercase_map["they're"] == 2])
      |> Kernel.++([lowercase_map["it's"] == 1])
      |> Enum.reduce(0, fn x, acc -> if x, do: acc + 1, else: acc end)

    IO.inspect("Task 3: #{valid_number}/#{total} ")
    IO.inspect(lowercase_map)
  end
end
