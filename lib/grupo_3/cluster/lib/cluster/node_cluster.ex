defmodule Cluster.NodeCluster do
  use GenServer

  def start_link(:ok) do
    GenServer.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    pid = spawn(fn -> setup_node() end)
    {:ok, pid}
  end

  def setup_node do
    # Setting ip node
    list_kind_of_networks = [~c"eth0", ~c"wlan0", ~c"en0"]

    ip = list_kind_of_networks |> get_ip()

    if ip == :undefined do
      {:error,
       "It not posible to identify an ip for the network in the following networks channels: #{Enum.join(list_kind_of_networks, ", ")}"}
    else
      node_name = get_name_node(ip)
      Node.stop()
      System.cmd("epmd", ["-daemon"])
      {status, _} = Node.start(node_name)

      if status == :ok do
        Node.set_cookie(:PLXATUNGSDBIRVZNZSKB)

        _ = Node.connect(:"nerves@#{"192.168.0.6"}")

        _ = Node.list()
        {status, "Node successfully configurated"}
      else
        # Wait until load all system
        Node.stop()
        setup_node()
      end
    end
  end

  def get_name_node(postfix) do
    if target() == :host do
      :"nerves@#{postfix}"
    else
      :"#{Toolshed.hostname()}@#{postfix}"
    end
  end

  def get_ip(list_kind_of_networks, tries \\ 60) do
    network_map = :inet.getifaddrs() |> elem(1) |> Map.new()

    networks_available =
      Enum.filter(list_kind_of_networks, fn k ->
        ipv4_addres(network_map, k) != nil
      end)

    if(Enum.count(networks_available) > 0) do
      ipv4_addres(network_map, Enum.at(networks_available, 0))
    else
      if tries > 0 do
        Process.sleep(1000)
        get_ip(list_kind_of_networks, tries - 1)
      else
        :undefined
      end
    end
  end

  def target do
    Application.get_env(:cluster, :target)
  end

  def ipv4_addres(network_map, id_network) do
    unless Map.has_key?(network_map, id_network) do
      nil
    else
      feature_network = network_map |> Map.get(id_network) |> Keyword.get_values(:addr)
      ip = feature_network |> Enum.find(&match?({_, _, _, _}, &1))
      unless ip == nil, do: ip |> Tuple.to_list() |> Enum.join("."), else: nil
    end
  end
end
