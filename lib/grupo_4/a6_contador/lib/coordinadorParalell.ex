defmodule ContadorPalabras.Coordinador do
  use GenServer

  # Iniciar el GenServer con un nombre dado para facilitar la referencia
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{contador: %{}, pendientes: 0, total: 0, total_palabras: 0}, opts)
  end

  # Función pública para iniciar el conteo desde un archivo
  def iniciar_contador_desde_archivo(ruta_archivo) do
    GenServer.cast(:coordinador, {:contar_archivo, ruta_archivo})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:contar_archivo, ruta_archivo}, state) do
    nodos = Node.list() |> Enum.concat([Node.self()])
    IO.inspect(nodos, label: "Nodos detectados conectados")

    texto = leer_archivo(ruta_archivo)
    partes = dividir_texto(texto, Enum.count(nodos))
    IO.inspect(partes, label: "Proceso de división del texto")

    Enum.each(Enum.zip(partes, nodos), fn {parte, nodo} ->
      IO.puts("Enviando parte a nodo: #{inspect nodo}")
      Task.start(fn ->
        {:ok, resultado} = :rpc.call(nodo, ContadorPalabras.Trabajador, :count, [parte])
        GenServer.cast(:coordinador, {:resultado, resultado})
      end)
    end)

    {:noreply, %{state | pendientes: Enum.count(nodos), total: Enum.count(nodos)}}
  end

  @impl true
  def handle_cast({:resultado, resultado}, state) do
    updated_contador = Map.merge(state.contador, resultado, fn _key, v1, v2 -> v1 + v2 end)
    updated_pendientes = state.pendientes - 1
    total_palabras = Map.values(resultado) |> Enum.sum()
    new_total_palabras = state.total_palabras + total_palabras

    IO.inspect(resultado, label: "Recepción del conteo de palabras del texto de un nodo")

    if updated_pendientes == 0 do
      IO.inspect(updated_contador, label: "Conteo definitivo de todo el texto")
      IO.puts("Total de palabras contadas: #{new_total_palabras}")
      {:noreply, %{state | contador: %{}, pendientes: state.total, total: state.total, total_palabras: 0}}
    else
      {:noreply, %{state | contador: updated_contador, pendientes: updated_pendientes, total_palabras: new_total_palabras}}
    end
  end

  defp leer_archivo(ruta_archivo) do
    File.read(ruta_archivo)
  end

  defp dividir_texto(texto, num_nodos) do
    case texto do
      {:ok, contenido} ->
        palabras = contenido |> String.split(~r/\s+/, trim: true)
        Enum.chunk_every(palabras, div(length(palabras), num_nodos), div(length(palabras), num_nodos), [])
      {:error, _reason} ->
        raise "Error al leer el archivo"
    end
  end
end
