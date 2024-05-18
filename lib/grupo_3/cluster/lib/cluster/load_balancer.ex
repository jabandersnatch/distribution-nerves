defmodule Cluster.LoadBalancer do
  use GenServer

  # Client

  def start_link(pos \\ 0, name \\ MyBalancer) do
    GenServer.start_link(__MODULE__, pos, name: name)
  end

  # Server (callbacks)

  @impl true
  def init(pos) do
    {:ok, pos}
  end

  @impl true
  def handle_call({:get_node}, _from, pos) do
    node_list = Node.list() ++ [Node.self()]
    pos = pos + 1
    pos = if pos >= Enum.count(node_list), do: 0, else: pos

    {:reply, Enum.at(node_list, pos), pos}
  end

  @impl true
  def handle_call({:get_node_list}, _from, pos) do
    node_list = Node.list() ++ [Node.self()]
    {:reply, node_list, pos}
  end

  def get_node(name_genserver \\ MyBalancer) do
    GenServer.call(name_genserver, {:get_node})
  end

  def get_node_lists(name_genserver \\ MyBalancer) do
    GenServer.call(name_genserver, {:get_node_list})
  end

  def stop(name_genserver \\ MyBalancer) do
    unless(GenServer.whereis(MyBalancer) == nil) do
      GenServer.stop(name_genserver)
    end
  end

  def test(times \\ 10) do
    Enum.each(0..times, fn _ ->
      spawn(fn ->
        list = [Node.self(), Node.list()]
        IO.inspect Enum.random(list)
      end)
    end)
  end
end
