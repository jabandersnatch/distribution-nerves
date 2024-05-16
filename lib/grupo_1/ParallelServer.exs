defmodule ParallelServer do
  @doc """
  Starts node to be visible in network
  """
  def start_node do
    # set name of node based on hostname
    {:ok, hostname} = :inet.gethostname()
    # start node
    Node.start(String.to_atom("livebook@#{hostname}"))
    # set cookie
    Node.set_cookie(:secure)
    # return name of node
    Node.self()
  end

  @doc """
  Create connections between nodes
  """
  def connect_node(node_name) do
    # connect node to other node
    Node.connect(String.to_atom(node_name))
  end

  @doc """
  Execute a distributed task, expects a partition_fun, function that from data create a list
  with information necessary to do the task individually, original_data, that is the whole
  data of the problem, a processing_fun that is in charge of process the data for each node,
  and finally a merge_function that after each node compute data is in charge of merge the information
  """
  def execute_distributed_task(original_data, partition_fun, merge_fun, persistence_fun, processing_fun) do
    # nodes including itself
    nodes = [Node.self() | Node.list()]
    n = length(nodes)
    # initial state
    state = {self(), Enum.map(1..n, fn _ -> false end), Enum.map(1..n, fn _ -> false end)}
    # starts monitor PID that will monitor different responses from different nodes
    monitor_pid = spawn(fn -> listen_monitor(state) end)
    # list with data specific for computation in each node
    data_partition_list = partition_fun.(original_data, n)
    # for all nodes including itself
    [nodes, data_partition_list, 1..n]
    |> Enum.zip()
    |> Enum.map(fn {node, data_partition_element, i} ->
      # starts a process in each node to be prepared for listen
      pid = Node.spawn_link(node, fn -> listen_node(processing_fun) end)
      # sends a message to each node to start processing of data
      send(pid, {:process_data, monitor_pid, data_partition_element, original_data, i})
    end)
    # after send all the differents pids stays waiting for the final partitioned data to be merges
    result = receive do
      {:merge_response, list_to_merge} ->
        merge_fun.(list_to_merge)
    end
    # if some data need to be save images or something
    IO.inspect(result)
    persistence_fun.(result)
  end

  @doc """
  From the node listen to the monitor orders this just happens once so it does not call listen_node
  at the end
  """
  def listen_node(processing_fun) do
    # this process is initialized from the monitor
    receive do
      {:process_data, monitor_pid, data_partition, original_data, i} ->
        IO.puts("Inicio de Ejecución desde Nodo: #{Node.self()}")
        # the "processing_fun" should be declared also in the other node
        processed_data = processing_fun.(data_partition, original_data)
        # una vez procesada se envia la información al nodo monitor (que inicio la tarea distribuida)
        send(monitor_pid, {:processed_data, processed_data, i})
    end
  end

  @doc """
  From the node that start the task he will be listening to the different nodes expecting to get responses for
  each node
  """
  def listen_monitor({pid_origin, data_response, completition_list}) do
    receive do
      {:processed_data, processed_result, i} ->
        # receive information from one node
        IO.puts("Recepción de Respuesta desde Nodo Monitor: #{Node.self()}")
        # adds ra true into completition list to mantain record of result completition
        new_completition_list = List.replace_at(completition_list, i-1, true)
        # adds data response to a list
        new_data_response = List.replace_at(data_response, i-1, processed_result)
        IO.inspect({new_completition_list,new_data_response})
        # if all data is completed returns response to original PID who is waiting for response
        if Enum.all?(new_completition_list, fn x -> x == true end) do
          IO.puts("Respuesta completa enviando")
          send(pid_origin,{:merge_response, new_data_response})
        else
          # if is not completed call itself to wait for other responses
          listen_monitor({pid_origin, new_data_response, new_completition_list})
        end
    end
  end
end

defmodule TestFunctions do
  @doc """
  Test function to partition data
  """
  def test_partition_fun(data, n) do
    data_partition_list = Enum.map(1..n, fn x -> "data #{x}" end)
  end

  @doc """
  Test processing fun
  """
  def test_processing_fun(data, original_data) do
    "| #{data} processed by #{Node.self()} |"
  end

  @doc """
  Test merge fun
  """
  def test_merge_fun(list) do
    Enum.reduce(list, "", fn str, acc -> acc <> str end)
  end

  @doc """
  Test persistence fun
  """
  def test_persistence_fun(result) do
    IO.puts("result")
    IO.inspect(result)
  end
end
