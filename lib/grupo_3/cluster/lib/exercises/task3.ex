## autor: Eder Leandro Carbonero Baquero
# All translation or adaptation was carried out by Eder Carbonero.
## This code was based on a python code found on internet
# https://github.com/antonmdv/Morphing/tree/master
defmodule Exercises.Task3 do
  alias Cluster.TaskCall

  def test(numMorphedFrames \\ 10) do
    numMorphedFrames = if numMorphedFrames < 1, do: 1, else: numMorphedFrames
    root_folder = if target() == :host, do: :code.priv_dir(:cluster), else: "/root/priv"
    img1 = read("#{root_folder}/source_images/P1.png", Image1)
    img2 = read("#{root_folder}/source_images/P2.png", Image2)
    destination_folder = "#{root_folder}/output_images"
    image_list = beier_neely(img1, img2, numMorphedFrames)
    write_images(image_list, destination_folder)
  end

  def beier_neely(name_image1, name_image2, numMorphedFrames \\ 1) do
    width = Data.ImageInMemory.get_width(name_image1)
    height = Data.ImageInMemory.get_height(name_image1)

    # DeltaP and DeltaQ
    d_P = divide_matrix(sustra_matrix(destP(), srcP()), numMorphedFrames + 1)

    d_Q = divide_matrix(sustra_matrix(destQ(), srcQ()), numMorphedFrames + 1)

    Enum.map(0..numMorphedFrames, fn each_frame ->
      Task.async(fn ->
        interpolatedP = additing_matrix(srcP(), multiply_matrix(d_P, each_frame + 1))
        interpolatedQ = additing_matrix(srcQ(), multiply_matrix(d_Q, each_frame + 1))

        num_chucks =
          floor(
            height /
              (Enum.count(Cluster.LoadBalancer.get_node_lists()) *
                 :erlang.system_info(:logical_processors_available))
          )

        chucks = Enum.to_list(0..(height - 1)) |> Enum.chunk_every(num_chucks)

        IO.puts("Number of chucks: #{Enum.count(chucks)}")

        pixel_map =
          Enum.map(chucks, fn chuck ->
            Task.async(fn ->
              Cluster.TaskCall.run_sync_auto_detect(
                Exercises.Task3,
                :process_group_of_rows,
                [
                  chuck,
                  width,
                  interpolatedP,
                  interpolatedQ,
                  each_frame,
                  numMorphedFrames,
                  name_image1,
                  name_image2
                ]
              )
            end)
          end)
          |> Task.await_many(900_000)
          |> Enum.reverse()
          |> Enum.reduce([], fn pixel, acc -> pixel ++ acc end)

        get_new_image(name_image1, pixel_map)
      end)
    end)
    |> Task.await_many(900_000)
  end

  def write_images(image_list, destination_folder) do
    Enum.each(0..(Enum.count(image_list) - 1), fn pos ->
      IO.puts("Saving images #{pos}")
      write_image(Enum.at(image_list, pos), "#{destination_folder}/beier_neely#{pos}.png")
    end)
  end

  def write_image(image, path) do
    Imagineer.write(image, path)
  end

  def process_group_of_rows(
        chuck,
        width,
        interpolatedP,
        interpolatedQ,
        each_frame,
        numMorphedFrames,
        name_image1,
        name_image2
      ) do
    img1 = Data.ImageInMemory.get_image(name_image1)
    img2 = Data.ImageInMemory.get_image(name_image2)
    height = Data.ImageInMemory.get_height(name_image1)

    Enum.map(chuck, fn h ->
      Enum.map(0..(width - 1), fn w ->
        pixel = [w, h]
        dSUM1 = [0.0, 0.0]
        dSUM2 = [0.0, 0.0]
        weightsum = 0

        srcP_length = Enum.count(srcP()) - 1

        {dSUM1, dSUM2, weightsum} =
          Enum.reduce(
            0..srcP_length,
            {dSUM1, dSUM2, weightsum},
            fn line, {dSUM1, dSUM2, weightsum} ->
              vP = Enum.at(interpolatedP, line)
              vP1 = Enum.at(srcP(), line)
              vP2 = Enum.at(destP(), line)
              vQ = Enum.at(interpolatedQ, line)
              vQ1 = Enum.at(srcQ(), line)
              vQ2 = Enum.at(destQ(), line)

              pU0 = dot(sustra_matrix(pixel, vP), sustra_matrix(vQ, vP))

              pU1 =
                vectorial_norm(sustra_matrix(vQ, vP)) *
                  vectorial_norm(sustra_matrix(vQ, vP))

              pU = pU0 / pU1

              pV0 =
                dot(
                  sustra_matrix(pixel, vP),
                  perpendicular(sustra_matrix(vQ, vP))
                )

              pV1 = vectorial_norm(sustra_matrix(vQ, vP))
              pV = pV0 / pV1

              xPrime1_0 =
                additing_matrix(vP1, multiply_matrix(sustra_matrix(vQ1, vP1), pU))

              xPrime1_1 =
                multiply_matrix(perpendicular(sustra_matrix(vQ1, vP1)), pV)

              xPrime1_2 = vectorial_norm(sustra_matrix(vQ1, vP1))

              xPrime1 =
                additing_matrix(xPrime1_0, divide_matrix(xPrime1_1, xPrime1_2))

              ###################
              xPrime2_0 =
                additing_matrix(vP2, multiply_matrix(sustra_matrix(vQ2, vP2), pU))

              xPrime2_1 =
                multiply_matrix(perpendicular(sustra_matrix(vQ2, vP2)), pV)

              xPrime2_2 = vectorial_norm(sustra_matrix(vQ2, vP2))

              xPrime2 =
                additing_matrix(xPrime2_0, divide_matrix(xPrime2_1, xPrime2_2))

              displacement1 = sustra_matrix(xPrime1, pixel)
              displacement2 = sustra_matrix(xPrime2, pixel)

              # get shortest distance from P to Q
              shortestDist =
                cond do
                  pU >= 1 -> vectorial_norm(sustra_matrix(vQ, pixel))
                  pU <= 0 -> vectorial_norm(sustra_matrix(vP, pixel))
                  pU < 1 && pU > 0 -> Kernel.abs(pV)
                end

              lineWeight =
                (vectorial_norm(sustra_matrix(vP, vQ)) ** m() / (a() + shortestDist)) ** b()

              dSUM1 = additing_matrix(dSUM1, multiply_matrix(displacement1, lineWeight))

              dSUM2 = additing_matrix(dSUM2, multiply_matrix(displacement2, lineWeight))

              weightsum = weightsum + lineWeight
              {dSUM1, dSUM2, weightsum}
            end
          )

        # displace X' with the sums

        xPrime1 = additing_matrix(pixel, divide_matrix(dSUM1, weightsum))
        xPrime2 = additing_matrix(pixel, divide_matrix(dSUM2, weightsum))

        # get destenation in the new image
        srcX = int(Enum.at(xPrime1, 0))
        srcY = int(Enum.at(xPrime1, 1))
        destX = int(Enum.at(xPrime2, 0))
        destY = int(Enum.at(xPrime2, 1))

        # if pixel is in range of the picture,then get color
        # else get color from current pixel

        srcRGB =
          if Enum.find(0..(width - 1), fn x -> x == srcX end) != nil and
               Enum.find(0..(height - 1), fn y -> y == srcY end) != nil do
            Enum.at(Map.get(img1, :pixels), srcY) |> Enum.at(srcX)
          else
            Enum.at(Map.get(img1, :pixels), h) |> Enum.at(w)
          end

        destRGB =
          if Enum.find(0..(width - 1), fn x -> x == destX end) != nil and
               Enum.find(0..(height - 1), fn y -> y == destY end) != nil do
            Enum.at(Map.get(img2, :pixels), destY) |> Enum.at(destX)
          else
            Enum.at(Map.get(img2, :pixels), h) |> Enum.at(w)
          end

        wI2 = 2 * (each_frame + 1) * (1 / (numMorphedFrames + 1))
        wI1 = 2 - wI2

        r = (wI1 * elem(srcRGB, 0) + wI2 * elem(destRGB, 0)) / 2
        g = (wI1 * elem(srcRGB, 1) + wI2 * elem(destRGB, 1)) / 2
        b = (wI1 * elem(srcRGB, 2) + wI2 * elem(destRGB, 2)) / 2
        {int(r), int(g), int(b)}
      end)
    end)
  end

  def get_new_image(name_image, pixel_map) do
    img1 = Data.ImageInMemory.get_image(name_image)

    %Imagineer.Image.PNG{
      alias: Map.get(img1, :alias),
      width: Map.get(img1, :width),
      height: Map.get(img1, :height),
      bit_depth: Map.get(img1, :bit_depth),
      color_type: Map.get(img1, :color_type),
      color_format: Map.get(img1, :color_format),
      uri: Map.get(img1, :uri),
      format: Map.get(img1, :format),
      attributes: Map.get(img1, :attributes),
      data_content: Map.get(img1, :data_content),
      raw: Map.get(img1, :raw),
      comment: Map.get(img1, :comment),
      mask: Map.get(img1, :mask),
      compression: Map.get(img1, :compression),
      decompressed_data: Map.get(img1, :decompressed_data),
      unfiltered_rows: Map.get(img1, :unfiltered_rows),
      scanlines: Map.get(img1, :scanlines),
      filter_method: Map.get(img1, :filter_method),
      interlace_method: Map.get(img1, :interlace_method),
      gamma: Map.get(img1, :gamma),
      palette: Map.get(img1, :palette),
      pixels: pixel_map,
      mime_type: Map.get(img1, :mime_type),
      background: Map.get(img1, :background),
      transparency: Map.get(img1, :transparency)
    }
  end

  def read(path, name_image \\ MyImage) do
    {:ok, image} = Imagineer.load(path)

    Enum.map(
      Cluster.LoadBalancer.get_node_lists(),
      fn node ->
        Task.async(fn ->
          TaskCall.run_sync_auto_detect(node, Data.ImageInMemory, :start_link, [
            image,
            name_image
          ])
        end)
      end
    )
    |> Task.await_many(:infinity)

    name_image
  end

  def int(number) do
    if number >= 0, do: floor(number), else: ceil(number)
  end

  def vectorial_norm(vector) do
    Enum.reduce(vector, 0, fn x, acu -> x * x + acu end) |> Math.sqrt()
  end

  def dot(matri_a, matrix_b) do
    Enum.at(matri_a, 0) * Enum.at(matrix_b, 0) + Enum.at(matri_a, 1) * Enum.at(matrix_b, 1)
  end

  def sustra_matrix(matrix_a, matrix_b) when is_list(matrix_a) and is_list(matrix_b) do
    boolean = is_list(Enum.at(matrix_a, 0))
    matrix_a = if is_list(Enum.at(matrix_a, 0)), do: matrix_a, else: [matrix_a]
    matrix_b = if is_list(Enum.at(matrix_b, 0)), do: matrix_b, else: [matrix_b]

    result =
      Enum.map(0..(Enum.count(matrix_a) - 1), fn row ->
        a = (Enum.at(matrix_a, row) |> Enum.at(0)) - (Enum.at(matrix_b, row) |> Enum.at(0))
        b = (Enum.at(matrix_a, row) |> Enum.at(1)) - (Enum.at(matrix_b, row) |> Enum.at(1))
        [a, b]
      end)

    if boolean, do: result, else: List.first(result)
  end

  def additing_matrix(matrix_a, matrix_b) do
    boolean = is_list(Enum.at(matrix_a, 0))
    matrix_a = if is_list(Enum.at(matrix_a, 0)), do: matrix_a, else: [matrix_a]
    matrix_b = if is_list(Enum.at(matrix_b, 0)), do: matrix_b, else: [matrix_b]

    result =
      Enum.map(0..(Enum.count(matrix_a) - 1), fn row ->
        a = (Enum.at(matrix_a, row) |> Enum.at(0)) + (Enum.at(matrix_b, row) |> Enum.at(0))
        b = (Enum.at(matrix_a, row) |> Enum.at(1)) + (Enum.at(matrix_b, row) |> Enum.at(1))
        [a, b]
      end)

    if boolean, do: result, else: List.first(result)
  end

  def divide_matrix(matrix, scalar) do
    boolean = is_list(Enum.at(matrix, 0))
    matrix = if is_list(Enum.at(matrix, 0)), do: matrix, else: [matrix]

    result =
      Enum.map(matrix, fn row ->
        a = Enum.at(row, 0) / scalar
        b = Enum.at(row, 1) / scalar
        [a, b]
      end)

    if boolean, do: result, else: List.first(result)
  end

  def multiply_matrix(matrix, scalar) do
    boolean = is_list(Enum.at(matrix, 0))
    matrix = if is_list(Enum.at(matrix, 0)), do: matrix, else: [matrix]

    result =
      Enum.map(matrix, fn row ->
        a = Enum.at(row, 0) * scalar
        b = Enum.at(row, 1) * scalar
        [a, b]
      end)

    if boolean, do: result, else: List.first(result)
  end

  def perpendicular([a, b]) do
    [-b, a]
  end

  def a do
    0.2
  end

  def b do
    1.25
  end

  def m do
    0.1
  end

  def srcP do
    [
      [200, 72],
      [94, 142],
      [84, 142],
      [306, 363],
      [100, 145],
      [237, 190],
      [131, 170],
      [304, 307],
      [161, 137],
      [204, 275],
      [207, 180]
    ]
  end

  def srcQ do
    [
      [94, 142],
      [84, 142],
      [306, 363],
      [189, 258],
      [207, 208],
      [205, 207],
      [304, 307],
      [207, 151],
      [204, 275],
      [207, 180],
      [272, 205]
    ]
  end

  def destP do
    [
      [243, 55],
      [91, 158],
      [65, 147],
      [290, 393],
      [90, 140],
      [250, 205],
      [112, 172],
      [300, 327],
      [161, 137],
      [204, 275],
      [207, 180]
    ]
  end

  def destQ do
    [
      [91, 158],
      [65, 147],
      [290, 393],
      [200, 272],
      [208, 215],
      [208, 212],
      [300, 327],
      [225, 172],
      [204, 275],
      [207, 180],
      [272, 205]
    ]
  end

  def target do
    Application.get_env(:cluster, :target)
  end
end
