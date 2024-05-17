defmodule Grupo0.Task1.Task1 do
  @doc """
  Count the number of words in the sentence.
  Words are compared case-insensitively.
  """
  @spec count_para(String.t()) :: map
  def count_para(phrase) do
    downcase = String.downcase(phrase)
    l = String.split(downcase, ~r/\s+/)
    count_para(l, length(l))
  end

  defp count_para(list, len) when len <= 1000 do
    count_list(list)
  end

  defp count_para(l, len) do
    {left, right} = Enum.split(l, div(len, 2))
    lp = Task.async(fn -> count_para(left, div(len, 2)) end)
    rp = count_para(right, div(len, 2))

    Map.merge(Task.await(lp), rp, fn _, val1, val2 ->
      val1 + val2
    end)
  end

  defp count_list(list) do
    count_map = %{}
    count_list(list, count_map)
  end

  defp count_list([head | tail], count_map) do
    if(Map.has_key?(count_map, head)) do
      updated_count_map = Map.update!(count_map, head, &(&1 + 1))
      count_list(tail, updated_count_map)
    else
      updated_count_map = Map.put(count_map, head, 1)
      count_list(tail, updated_count_map)
    end
  end

  defp count_list([], count_map) do
    count_map
  end

  def divide_string(string, pos) do
    IO.inspect(pos)
    IO.inspect(String.at(string, pos))

    if(String.at(string, pos) !== " " or String.at(string, pos) !== nil) do
      divide_string(string, pos - 1)
    else
      {String.slice(string, 0..(pos - 1)), String.slice(string, (pos + 1)..String.length(string))}
    end
  end

  def union_fun(lp, rp) do
    Map.merge(lp, rp, fn _, val1, val2 ->
      val1 + val2
    end)
  end

  def partition_fun(text, n) do
    String.split(text, ~r/\s+/)
    |> divide(n)
    |> Enum.map(fn x ->
      # IO.inspect(x)
      Enum.join(x, " ")
    end)
  end

  def divide(list, n) when is_list(list) and is_integer(n) and n > 0 do
    # Calcular la base y el excedente
    total_length = length(list)
    base_size = div(total_length, n)
    extra = rem(total_length, n)

    # Función para obtener el tamaño de cada parte
    get_size = fn
      index when index < extra -> base_size + 1
      _ -> base_size
    end

    # Generar las partes
    generate_parts(list, n, get_size)
  end

  defp generate_parts(list, n, get_size, index \\ 0, acc \\ [])

  defp generate_parts(_list, n, _get_size, n, acc), do: Enum.reverse(acc)

  defp generate_parts(list, n, get_size, index, acc) do
    size = get_size.(index)
    {part, rest} = Enum.split(list, size)
    generate_parts(rest, n, get_size, index + 1, [part | acc])
  end
end
