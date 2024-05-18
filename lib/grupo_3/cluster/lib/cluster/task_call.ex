defmodule Cluster.TaskCall do
  alias Cluster.LoadBalancer

  def process(node, pid, patter_pid, module, function_name, args) do
    response = Kernel.apply(module, function_name, args)
    Node.spawn(node, fn -> Kernel.send(pid, {patter_pid, response}) end)
  end

  def run_sync_in(node, module, function_name, args) do
    task =
      Task.async(fn ->
        receive do
          {:ok, response} ->
            response

          _ ->
            {:error}
        end
      end)

    response = Kernel.apply(module, function_name, args)
    Node.spawn(node, fn -> Kernel.send(task.pid, {:ok, response}) end)
    Task.await(task, :infinity)
  end

  def run_sync_in(node, function, args) do
    task =
      Task.async(fn ->
        receive do
          {:ok, response} ->
            response

          _ ->
            {:error}
        end
      end)

    response = Kernel.apply(function, args)
    Node.spawn(node, fn -> Kernel.send(task.pid, {:ok, response}) end)
    Task.await(task, :infinity)
  end

  def run_sync_auto_detect(node \\ nil, module, function_name, args) do
    task =
      Task.async(fn ->
        receive do
          {:ok, response} ->
            response

          _ ->
            IO.inspect("Error, something when wrong")
            {:error}
        end
      end)

    node = if node == nil, do: LoadBalancer.get_node(), else: node

    Node.spawn(node, fn ->
      Kernel.send(task.pid, {:ok, Kernel.apply(module, function_name, args)})
    end)

    Task.await(task, :infinity)
  end

  def run_sync_auto(node \\ nil, function, args) do
    task =
      Task.async(fn ->
        receive do
          {:ok, response} ->
            response

          _ ->
            {:error}
        end
      end)

    node = if node == nil, do: LoadBalancer.get_node(), else: node

    Node.spawn(node, fn ->
      Kernel.send(task.pid, {:ok, Kernel.apply(function, args)})
    end)

    Task.await(task, :infinity)
  end

  # Node.spawn(n, fn -> Cluster.Tasknodecallback.process(Node.self(), pid, 123, Cluster.Tasknodecallback, :add, [2, 3]) end)
end
