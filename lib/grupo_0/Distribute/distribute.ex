defmodule Grupo0.Distribute.Distribute do
  def actor(
        fun,
        union_fun,
        partition_fun,
        result,
        id,
        save_fun \\ nil,
        nodes \\ 0,
        initial_result \\ nil,
        initial_time \\ nil
      ) do
    receive do
      {:start, value} ->
        initial_time = DateTime.utc_now()
        IO.puts("Starting proccess")
        initial_result = result
        initial_node = node()
        n = length(Node.list()) + 1
        partitions = partition_fun.(value, n)

        (Node.list() ++ [node()])
        |> Enum.zip_with(partitions, fn node_name, partition ->
          Node.spawn(node_name, fn -> send(id, {:process, partition, initial_node}) end)
        end)

        actor(
          fun,
          union_fun,
          partition_fun,
          result,
          id,
          save_fun,
          n,
          initial_result,
          initial_time
        )

      {:process, value, initial_node} ->
        IO.puts("Proccessing data")
        final_value = fun.(value)
        Node.spawn(initial_node, fn -> send(id, {:final, final_value}) end)

        actor(
          fun,
          union_fun,
          partition_fun,
          result,
          id,
          save_fun,
          nodes,
          initial_result,
          initial_time
        )

      {:final, value} ->
        nodes = nodes - 1
        IO.inspect("Final step")
        IO.inspect(value)
        IO.inspect(result)
        v = union_fun.(result, value)

        if(nodes == 0) do
          final_time = DateTime.utc_now()
          IO.puts("Time of process in milliseconds: ")
          IO.inspect(DateTime.diff(final_time, initial_time, :millisecond))
          IO.puts("Final data: ")
          IO.inspect(v)

          if save_fun != nil do
            save_fun.(v)
          end

          actor(
            fun,
            union_fun,
            partition_fun,
            initial_result,
            id,
            save_fun,
            nodes,
            initial_result,
            nil
          )
        else
          actor(
            fun,
            union_fun,
            partition_fun,
            v,
            id,
            save_fun,
            nodes,
            initial_result,
            initial_time
          )
        end
    end
  end
end
