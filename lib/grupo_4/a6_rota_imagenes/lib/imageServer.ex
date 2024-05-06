defmodule ImageServer do
  use GenServer

  # Inicia el GenServer
  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, %{contador: %{}, pendientes: 0, total: 0}, name: :image_server)
  end

  # Función pública para iniciar el conteo desde un archivo
  def iniciar_contador_desde_archivo(ruta_carpeta, angulo) do
    GenServer.cast(:image_server, {:contar_imagenes, ruta_carpeta, angulo})
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_cast({:contar_imagenes, folder_path, angle}, state) do
    images = get_images_from_folder(folder_path)
    nodes = Node.list() |> Enum.concat([Node.self()])
    Enum.each(images, fn image_path ->
      node = Enum.random(nodes)
      GenServer.cast(node, {:rotate_image, image_path, angle})
    end)

    {:noreply, %{state | pendientes: length(images)}}
  end

  defp get_images_from_folder(folder_path) do
    File.ls!(folder_path)
    |> Enum.map(&Path.join(folder_path, &1))
    |> Enum.filter(&File.regular?/1)
  end
end
