# Grupo 1
## Integrantes
- Daniel Fernando Gómez Barrera, df.gomezb@uniandes.edu.co
- Marilyn Joven, m.joven@uniandes.edu.co
- Santiago Forero Gutierrez, s.forerog2@uniandes.edu.co

## Ejecución de Código

La manera recomendada para ejecutar el código de distribución es utilizando Livebook. La instalación de Livebook está disponible en https://livebook.dev/#install, existen entornos online de HugginFace para realizar pruebas con Notebooks de Elixir en Livebook. No se necesita instalar dependencias adicionales que no estén por defecto en Livebook.

Para probar los casos de prueba puede utilizar los dos notebooks disponibles:

- [ImageProcessing.livemd](https://github.com/jabandersnatch/distribution-nerves/blob/grupo-1/lib/grupo_1/ImageProcessing.livemd): Ejercicio de procesamiento de imágenes (voltear una imagen) este Notebook incluye en una celda la librería ParallelServer.exs. [Demostración de funcionamiento](https://youtu.be/b_kbHOR5Qv0).
- [TextProcessing.livemd](https://github.com/jabandersnatch/distribution-nerves/blob/grupo-1/lib/grupo_1/TextProcessing.livemd): Ejercicio de procesmiento de texto (conteo de palabras) este Notebook incluye en una celda la librería ParallelServer.exs. [Demostración de funcionamiento](https://youtu.be/iNE74siLbpQ).

Una vez importe el Notebook puede ejecutarlo, el código funciona independiente del número de nodos conectados. Si no cuenta con nodos adicionales igualmente puede correr el código, en ese caso la tarea se ejecutará únicamente en un nodo.

## Código de Paralelismo

El código de Paralelismo disponible en el Archivo dentro de la carpeta lib [ParallelServer.exs](https://github.com/jabandersnatch/distribution-nerves/blob/grupo-1/lib/grupo_1/ParallelServer.exs) contiene la implementación para paralelizar una tarea en diferentes nodos.

Las funciones dentro del código para manejo de conexiones entre nodos son las funciones de ``start_node`` que inicia el nodo en nerves asignandole un nombre al host y verificando la conexión, y ``connect_node`` que conecta un nodo con otro, incluyéndolo en la red de nodos.

```elixir
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
```

La función más importante dentro del código de paralelismo es la función ``execute_distributed_task``, la cual inicia el trabajo en paralelo, distribuye en los diferentes nodos, une y publica el resultado.

```elixir
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
```
La ejecución de la tarea sucede de la siguiente manera:

- Se listan todos los nodos disponibles incluyendo el nodo monitor como nodo de procesamiento
  
  ```elixir
  # nodes including itself
  nodes = [Node.self() | Node.list()]
  n = length(nodes)
  ```
- Se crea un estado, que corresponde a un mapa de tres elementos: PID del proceso en el nodo monitor que inicio la tarea, una lista de boleanos que indica el estado de completitud de la tarea paralela en cada uno de los nodos, y una lista con la información
  
  ```elixir
  # initial state
  state = {self(), Enum.map(1..n, fn _ -> false end), Enum.map(1..n, fn _ -> false end)}
  ```
- Se inicializa un proceso en el nodo monitor, que se encarga de monitorear el progreso de todos los nodos. Para esto se crea un proceso que ejecuta la función ``listen_monitor`` que se encarga de mantener el estado, cuando todos los nodos le han enviado la información al proceso este retorna la información al proceso que inicio la tarea para que este una la información y la retorne al usuario original en el proceso original.
  
  ```elixir
  def execute_distributed_task(...)
  ...
     # starts monitor PID that will monitor different responses from different nodes
     monitor_pid = spawn(fn -> listen_monitor(state) end)
  ...
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
  ```
- Se utiliza la función de partición para dividir la tarea y se realiza un recorrido de la lista, enviando a cada nodo el proceso con la información correspondiente. La función ``listen_node`` se ejecuta primero en el nodo, para que el nodo esté disponible para escuchar antes de recibir la señal de procesamiento.
  
  ```elixir
  def execute_distributed_task(...)
  ...
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
  ...
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
  ```
- Por último en el mismo proceso de ejecución original se hace un receive, que basicamente significa que el proceso se queda esperando a la respuesta del nodo monitor cuando ya tenga la información dividida para poder hacer el merge. Luego se utiliza la función de persistencia para publicar/guardar el resultado.
  
  ```elixir
  # after send all the differents pids stays waiting for the final partitioned data to be merges
  result = receive do
    {:merge_response, list_to_merge} ->
      merge_fun.(list_to_merge)
  end
  # if some data need to be save images or something
  IO.inspect(result)
  persistence_fun.(result)
  ```

``execute_distributed_task`` recibe por parámetro la definición de 4 funciones y 1 parámetro de data.

- original_data: Este es el input de toda la tarea, por ejemplo en el caso de rotar imágenes este parámetro es la imagen.
- partition_fun: Esta función debe recibir dos parámetros la data y n, donde la data es el input de la tarea y n el número de nodos. Esta función retorna una lista con la información dividida.
  
  ```elixir
  @doc """
  Test function to partition data
  """
  def test_partition_fun(data, n) do
    data_partition_list = Enum.map(1..n, fn x -> "data #{x}" end)
  end
  ```
- processing_fun: Esta función es la que se ejecutara en cada nodo individualmente para procesar paralelamente, recibe por parámetro la partición de data y retorna el resultado parcial.
  
  ```elixir
  @doc """
  Test processing fun
  """
  def test_processing_fun(data, original_data) do
    "| #{data} processed by #{Node.self()} |"
  end
  ```
- merge_fun: Esta función se encarga de unir los diferentes resultados de los nodos en uno solo, en el caso de la imagenes se le asigna una sección de la imagen rotada, por lo que luego del procesamiento se debe unir las secciones de imagen en una sola imagen. Esta función la ejecuta el nodo monitor (el que inicio la tarea).
  
  ```elixir
  @doc """
  Test merge fun
  """
  def test_merge_fun(list) do
    Enum.reduce(list, "", fn str, acc -> acc <> str end)
  end
  ```
- persistence_fun: Esta función se encarga de manejar el resultado, se puede utilizar para guardar el resultado o para publicarlo.
  
  ```elixir
  @doc """
  Test persistence fun
  """
  def test_persistence_fun(result) do
    IO.puts("result")
    IO.inspect(result)
  end
  ```

Todas las funciones anteriores son de test, debido a que dependiendo de la tarea que se realice estas funciones cambian. Es por esta razón que se reciben por parámetro, permitiendo aislar la librería de paralelismo de una tarea específica.

Para realizar el llamado a la ejecución desde cualquier nodo de la red con el módulo ``ParallelServer`` cargado ejecute (aqui se utiliza el ejemplo del ejercicio de conteo de palabras pero podría utilizar otras funciones dependiendo de la tarea que se realice):
```elixir
ParallelServer.execute_distributed_task(
          text,
          &Count.partition_fun/2,
          &Count.merge_fun/1,
          &Count.persistence_fun/1,
          &Count.processing_fun/2
        )
```

## Ejercicios

La explicación de los ejercicios fue parte de la entrega de la tarea por Bloque Neón. El documento entregado se puede revisar aqui -> [T6_Concurrencia.pdf](https://github.com/jabandersnatch/distribution-nerves/files/15456015/T6_Concurrencia.pdf)

### Benchmarks

Se colocan los resultados de la ejecución en paralelo de las diferentes tareas:

![image](https://github.com/jabandersnatch/distribution-nerves/assets/49533662/86418e84-130e-4e08-a61e-37dd043ff8c7)
