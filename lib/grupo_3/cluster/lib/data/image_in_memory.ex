defmodule Data.ImageInMemory do
  use GenServer

  # Client

  def start_link(image, name \\ MyImage) do
    stop(name)
    GenServer.start(__MODULE__, image, name: name)
  end

  # Server (callbacks)

  @impl true
  def init(image) do
    {:ok, image}
  end

  @impl true
  def handle_call({:get_pixel, x, y}, _from, image) do
    response =
      if Map.get(image, :pixels) |> Enum.at(y) == nil,
        do: {255, 255, 255},
        else: Map.get(image, :pixels) |> Enum.at(y) |> Enum.at(x)

    {:reply, response, image}
  end

  @impl true
  def handle_call({:get_width}, _from, image) do
    response = Map.get(image, :width)
    {:reply, response, image}
  end

  @impl true
  def handle_call({:get_height}, _from, image) do
    response = Map.get(image, :height)
    {:reply, response, image}
  end

  @impl true
  def handle_call({:get_image}, _from, image) do
    {:reply, image, image}
  end

  def get_pixel(name_genserver \\ MyImage, x, y) do
    GenServer.call(name_genserver, {:get_pixel, x, y})
  end

  def get_width(name_genserver \\ MyImage) do
    GenServer.call(name_genserver, {:get_width})
  end

  def get_height(name_genserver \\ MyImage) do
    GenServer.call(name_genserver, {:get_height})
  end

  def get_image(name_genserver \\ MyImage) do
    GenServer.call(name_genserver, {:get_image})
  end

  def stop(name_genserver \\ MyImage) do
    unless(GenServer.whereis(name_genserver) == nil) do
      GenServer.stop(name_genserver)
    end
  end

  def test_get_pixel(name_genserver \\ MyImage, x, y, tries \\ 10) do
    Enum.each(0..tries, fn _ ->
      spawn(fn -> GenServer.call(name_genserver, {:get_pixel, x, y}) end)
    end)
  end
end
