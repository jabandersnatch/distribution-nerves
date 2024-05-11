defmodule ComNerves do

  def test do
    configure(0)
    data_ex1 = "head 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 8 7 6 5 4 3 2 2 5 6 8 0 6 4 23 2 3 4 5 6 7 89 0 6 3 1 1 1 1 1 1 Hola hola HOLA HO,la 1 1 1 1 1 1 head"
    start_cluster(data_ex1, &Exercise1.e1_split_function/2, &Exercise1.e1_function/1, &Exercise1.e1_merge_function/2)
    #data_ex2 = ExPng.Image.from_file("assets/test_input.png");
    #start_cluster({data_ex2, 45}, &Exercise2.e2_split_function/2, &Exercise2.e2_function/1, &Exercise2.e2_merge_function/2)

  end

  def configure(_) do
    Node.start(:"com@127.0.0.1")
  end

  def start_cluster(data, fun_split, fun, converge) do
    size = connect_children()
    IO.puts("Nodes number: #{size}")
    parallel_constant = 3
    #Partir la información para iniciar los procesos con información distribuida
    #data = String.split(data, " ")


    headNode = start_head(size * parallel_constant, converge)
    childs = Node.list()
      |> Enum.with_index()
      |> Enum.flat_map( fn {node, index} -> Enum.map(0..parallel_constant, fn x -> start_child(node,  "#{index} #{x}") end) end)
    parallel_workers = length(childs)

    IO.puts("Splitting data")
    data_splited = fun_split.(data, parallel_workers)

    IO.puts("Executing functions")
    #Enviar la función junto con dato a cada nodo
    for {value, index} <- Enum.with_index(childs) do
      send(value, {:execute, fun, Enum.at(data_splited, index) , headNode})
    end
    :ok
  end


  def start_head(size, converge) do
    #configure_net(0)
    Node.spawn_link(Node.self(), fn -> loop_head(size, %{}, size, converge) end)
  end

  def loop_head(size, rta, workers, converge) do
    map = receive do
      {:end, _, data, index} ->  Map.put(rta, index, data)
      {:execute_head, data, fun, index} -> Map.put(rta, index, fun.(data))
    end
    case size do
      0 -> converge.(map, Map.keys(map))
      _ -> loop_head(size - 1, map, workers, converge)
    end
  end

  def start_child(node, index) do
    Node.spawn_link(node, fn -> loop_child(index) end )
  end

  def loop_child(index) do
    receive do
      {:execute, fun, data, pidOrigin} -> send(pidOrigin, {:end, Node.self(), fun.(data), index })
    end
  end

  # Conectar los nodos disponibles
  defp connect_children() do
    [:"node_0@127.0.0.1", :"node_1@127.0.0.1"] |> Enum.reduce(0, fn node, acc -> Node.connect(node); acc + 1 end )
  end


end


defmodule Exercise1 do

  def e1_function(data) do
    response = Enum.reduce data, %{}, fn x, acc ->
      word = String.downcase(x)
      word = String.replace(word, ~r/[!#$%&()*+,.:;<=>?@\^_`{|}~-]/, "")
      v = Map.get(acc, word)
      if v == nil do
        Map.put(acc, word, 1)
      else
        Map.put(acc, word, v+1)
      end
    end
    response
  end

  def e1_split_function(data, workers) do
    list = String.split(data, [" ", "\n", "\t"])
    size = length(list)
    a = div(size,workers)+1
    Enum.chunk_every(list, a)
  end

  def e1_merge_function(map, childs) do
    res = merge(map, childs, %{})
    IO.puts("Función de convergencia")
    Enum.each(res, fn {k, v} -> IO.puts("#{k} : #{v}") end )
  end

  def merge(map, [a | children], r) do
    r = Map.merge(r, map[a], fn _k, v1, v2 ->
      v1 + v2
    end)
    merge(map, children, r)
  end

  def merge(_, [], r) do
    r
  end
end

defmodule Exercise2 do
  import ExPng

  def load_image(path) do
    ExPng.Image.from_file(path)
  end

  def grados_a_radianes(grados) do
    grados * (:math.pi() / 180)
  end

  def additional_values(width, height, angle) do
    case angle do
      angle when angle > 0 and angle <= 90 ->
        rad = grados_a_radianes(angle)
        cos_angle = :math.cos(rad)
        sin_angle = :math.sin(rad)
        new_height = width * sin_angle + height * cos_angle
        new_width = height * sin_angle + width * cos_angle
        additional_width = 0
        additional_height = width * sin_angle
        {new_width, new_height, additional_width, additional_height}
      angle when angle > 90 and angle <= 180 ->
        rad = grados_a_radianes(180 - angle)
        cos_angle = :math.cos(rad)
        sin_angle = :math.sin(rad)
        new_width = width * cos_angle + height * sin_angle
        new_height = width * sin_angle + height * cos_angle
        additional_width = width * cos_angle
        additional_height = height * cos_angle + width * sin_angle
        {new_width, new_height, additional_width, additional_height}
      angle when angle > 180 and angle <= 270 ->
        rad = grados_a_radianes(270 - angle)
        cos_angle = :math.cos(rad)
        sin_angle = :math.sin(rad)
        new_height = width * cos_angle + height * sin_angle
        new_width = width * sin_angle + height * cos_angle
        additional_width = width * sin_angle + height * cos_angle
        additional_height = height * sin_angle
        {new_width, new_height, additional_width, additional_height}
      angle when angle > 270 and angle <= 360 ->
        rad = grados_a_radianes(360 - angle)
        cos_angle = :math.cos(rad)
        sin_angle = :math.sin(rad)
        new_width = width * cos_angle + height * sin_angle
        new_height = width * sin_angle + height * cos_angle
        additional_width = height * sin_angle
        additional_height = 0
        {new_width, new_height, additional_width, additional_height}
      _ -> {0,0,0,0}
      end
  end


  def e2_split_function({image, angle}, workers) do

    {:ok, %ExPng.Image{pixels: _, raw_data: _, height: height, width: width} = imageData } = image
    rad = grados_a_radianes(angle)
    cos_angle = :math.cos(rad)
    sin_angle = :math.sin(rad)

    IO.puts("Angle: #{angle}")
    IO.puts("Width: #{width}")
    IO.puts("Height: #{height}")


    {new_width, new_height, additional_width, additional_height} = additional_values(width, height, angle)
    new_image = ExPng.Image.new(trunc(new_width), trunc(new_height))

    height_package = div(height , workers) + 1

    Enum.map(0..workers-1, fn i ->
      {i, i * height_package,
       i * height_package + height_package,
       new_image,
       imageData,
       width,
       trunc(new_width),
       cos_angle,
       sin_angle,
       additional_width,
       additional_height}
    end)

  end

  def e2_function (
      {i,
       package_init,
       package_end,
       new_image,
       image,
       width,
       new_width,
       cos_angle,
       sin_angle,
       additional_width,
       additional_height}

  ) do
      IO.puts(i)
     image = Enum.reduce(package_init..package_end, new_image, fn y, acc ->
      Enum.reduce(0..width-1, acc, fn x, acc ->
          x_1 = trunc(cos_angle*x + sin_angle*y + additional_width )
          y_1 = trunc(-sin_angle*x + cos_angle*y + additional_height)
          ExPng.Image.Drawing.draw(acc, {x_1, y_1}, ExPng.Image.Drawing.at(image, {x, y}))
          # Añadir dentro de la lista el mapa de la posición y_1 para la lista de puntos y_1
        end)
      end)
      {i, package_init, package_end, image, new_width}
  end

  def e2_merge_function(images_map, _) do
    IO.puts("Merging images")
    {_, _,_, image, _} =
    Enum.reduce(Map.values(images_map), List.first(Map.values(images_map)),
      fn ({i, package_init, package_end, image_1, width},
         {_, _, _, image_0, width}) ->
          #Unir las IMAGENES
          {i,
          package_init,
          package_end,
          Enum.reduce(package_init..package_end, image_0, fn y, acc_0 ->
            Enum.reduce(0..width-1, acc_0,
              fn x, acc_1 ->
                color = ExPng.Image.Drawing.at(image_1, {x, y})
                if (color != ExPng.Color.white()) do
                  ExPng.Image.Drawing.draw(acc_1, {x, y}, color)
                else
                  acc_1
                end

                # Añadir dentro de la lista el mapa de la posición y_1 para la lista de puntos y_1
              end)
          end) ,
          width}
      end)
    IO.puts("Saving image as test_output.png in assets folder")
    saveImage(image)
  end

  def saveImage(image) do
    {:ok , rawData} = ExPng.Image.Encoding.to_raw_data(image)
    ExPng.RawData.to_file(rawData, "assets/test_output.png")
  end




end
