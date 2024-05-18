defmodule Data.PixelsProcessMap do
  use GenServer

  # Client
  # limit 262144

  def start_link(image, name) do
    stop(name)
    GenServer.start_link(__MODULE__, generate_process_map(image), name: name)
  end

  @impl true
  def init(image) do
    {:ok, image}
  end

  def pixel(value) do
    receive do
      {:set, new_value} ->
        pixel(new_value)

      {:get, pid} ->
        send(pid, {:ok, value})
        pixel(value)
    end
  end

  def start_pixel({r, g, b}) do
    spawn_link(Data.PixelsProcessMap, :pixel, [{r, g, b}])
  end

  defp generate_process_map(pixel_map) do
    width = Enum.count(pixel_map)
    heigth = Enum.count(Enum.at(pixel_map, 0))

    Enum.map(
      0..(width - 1),
      fn y ->
        Enum.map(
          0..(heigth - 1),
          fn x ->
            start_pixel(Enum.at(pixel_map, y) |> Enum.at(x))
          end
        )
      end
    )
  end

  def receive_pixel do
    receive do
      {:ok, value} -> value
    end
  end

  def create_receive_pixel_task do
    Task.async(Data.PixelsProcessMap, :receive_pixel, [])
  end

  def stop(name_genserver) do
    unless(GenServer.whereis(name_genserver) == nil) do
      GenServer.stop(name_genserver)
    end
  end

  @impl true
  def handle_call({:get_image}, _from, pixel_map) do
    width = Enum.count(pixel_map)
    heigth = Enum.count(Enum.at(pixel_map, 0))

    response =
      Enum.map(
        0..(width - 1),
        fn y ->
          Enum.map(
            0..(heigth - 1),
            fn x ->
              task = Task.async(fn -> receive_pixel() end)
              pid = Enum.at(pixel_map, y) |> Enum.at(x)
              send(pid, {:get, task.pid})
              Task.await(task)
            end
          )
        end
      )

    {:reply, response, pixel_map}
  end

  def get_image_pixel_map(name_genserver) do
    GenServer.call(name_genserver, {:get_image})
  end
end
