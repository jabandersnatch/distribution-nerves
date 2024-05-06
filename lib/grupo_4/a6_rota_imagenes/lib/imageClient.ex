defmodule ImageWorker do
  use GenServer
  require Mogrify

  # Iniciar el GenServer del trabajador
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, opts)
  end

  def init(state) do
    {:ok, state}
  end

  # Maneja la solicitud para rotar una imagen
  def handle_cast({:rotate_image, image_path, angle}, state) do
    output_path = "rotated_#{Path.basename(image_path)}"
    rotate_image(image_path, output_path, angle)
    GenServer.cast(:image_server, {:image_rotated, output_path})
    {:noreply, state}
  end

  # Función para rotar una imagen utilizando Mogrify
  defp rotate_image(input_path, output_path, angle) do
    input_path
    |> Mogrify.open()
    |> Mogrify.custom("rotate", Integer.to_string(angle))
    |> Mogrify.save(path: output_path)
  end
end
