defmodule Morphing do

  def test do
    morph_images("./cat.png", "./dog.png", "./cat_lines.txt","./dog_lines.txt",1, 4)
  end

  def morph_images(src_image_path, dest_image_path, src_lines_file, dest_lines_file, num_morphed_frames, num_processes) do
    {:ok, src_image} = load_image_nx(src_image_path)
    {:ok, dest_image} = load_image_nx(dest_image_path)
    {height, width, _} = Nx.shape(src_image)
    im_size = {width, height}

    src_lines = process_lines_file(src_lines_file)
    srcP_points = Enum.map(src_lines, fn {x1, y1, x2, y2} -> [x1, y1] end)
    srcQ_points = Enum.map(src_lines, fn {x1, y1, x2, y2} -> [x2, y2] end)

    dest_lines = process_lines_file(dest_lines_file)
    desP_points = Enum.map(dest_lines, fn {x1, y1, x2, y2} -> [x1, y1] end)
    desQ_points = Enum.map(dest_lines, fn {x1, y1, x2, y2} -> [x2, y2] end)


    # srcP_points = [[200, 72], [94, 142], [84, 142],
    #                [306, 363], [100, 145], [237, 190],
    #                [131, 170], [304, 307], [161, 137],
    #                [204, 275], [207, 180]]

    # srcQ_points = [[94, 142], [84, 142], [306, 363],
    #                [189, 258], [207, 208], [205, 207],
    #                [304, 307], [207, 151], [204, 275],
    #                [207, 180], [272, 205]]

    # desP_points = [[243, 55], [91, 158], [65, 147],
    #                [290, 393], [90, 140], [250, 205],
    #                [112, 172], [300, 327], [161, 137],
    #                [204, 275], [207, 180]]

    # desQ_points = [[91, 158], [65, 147], [290, 393],
    #                [200, 272], [208, 215], [208, 212],
    #                [304, 327], [225, 172], [204, 275],
    #                [207, 180], [272, 205]]

    d_p = calculate_delta(srcP_points, desP_points, num_morphed_frames)
    d_q = calculate_delta(srcQ_points, desQ_points, num_morphed_frames)

    for frame <- 0..num_morphed_frames do
      interpolated_p = interpolate_points(srcP_points, d_p, frame)
      interpolated_q = interpolate_points(desP_points, d_q, frame)
      morphed_im = create_image(im_size)

      IO.inspect(interpolated_p)
      IO.inspect(interpolated_q)
      slice_size = div(height, num_processes)

      finished = Enum.map(0..(num_processes-1), fn i ->
                  Task.async(fn -> process_slice(morphed_im, src_image, dest_image, interpolated_p, interpolated_q, slice_size*i, frame, num_morphed_frames) end)
                 end)
                |> Enum.map(&Task.await/1)


      joined = Enum.reduce(finished, [], fn x, acc -> acc ++ x end)



      save_image(Nx.tensor(joined), frame)
      IO.puts("Image #{frame + 1} was saved")
    end
  end

  defp load_image(path) do
    im_data = File.read(path)
    image = Pngex.new(type: :rgb, depth: :depth16, width: 340, height: 480) |> Pngex.generate(im_data)
    image
  end
  defp load_image_nx(path) do
    Image.open!(path)
    |> Image.to_nx
  end

  def process_lines_file(file_path) do
    File.read!(file_path)
    |> String.split("\n")
    |> Enum.map(&String.split(&1, " "))
    |> Enum.map(&List.to_tuple/1)
    |> Enum.map(fn {x,y} -> {String.split(x, ","), String.split(y, ",")} end)
    |> Enum.map(fn {x,y} -> {List.to_tuple(x), List.to_tuple(y)} end)
    |> Enum.map(fn {{x1,y1},{x2,y2}} -> {String.to_integer(x1), String.to_integer(y1), String.to_integer(x2), String.to_integer(y2)} end)
  end

  def save_image(image, frame) do
    image
    |> Image.from_nx
    |> Image.write("./morphed_#{frame}.png")
  end

  def create_image(size) do
    Nx.broadcast(0, size)
  end

  defp calculate_delta(src_points, dest_points, num_frames) do
    Enum.map(src_points, fn [x_src, y_src] ->
      [x_dest, y_dest] = Enum.at(dest_points, Enum.find_index(src_points, &(&1 == [x_src, y_src])))
      [(x_dest - x_src) / (num_frames + 1), (y_dest - y_src) / (num_frames + 1)]
    end)
  end

  defp calculate_norm(v1) do
    :math.pow(v1[0] * v1[0] + v1[1] * v1[1], 0.5)
  end

  defp calculate_dot(v1, v2) do
    v1[0] * v2[0] + v1[1] * v2[1]
  end

  defp perpendicular(a) do
    [-a[1], a[0]]
  end

  defp subtract(v1, v2) do
    [v1[0] - v2[0], v1[1] - v2[1]]
  end

  defp add(v1, v2) do
    [v1[0] + v2[0], v1[1] + v2[1]]
  end

  defp scale_vector(v1, scalar) do
    [v1[0] * scalar, v1[1] * scalar]
  end

  defp interpolate_points(points, delta, frame) do
    Enum.map(points, fn [x_src, y_src] ->
      [delta_x, delta_y] = Enum.at(delta, Enum.find_index(points, &(&1 == [x_src, y_src])))
      [x_src + delta_x * (frame + 1), y_src + delta_y * (frame + 1)]
    end)
  end

  # defp create_image(size) do
  #   Pngex.new(type: :rgb, depth: :depth16, width: 340, height: 480)
  # end

  defp process_pixel(morphed_im, src_image, dest_image, interpolated_p, interpolated_q, {w, h}, frame, num_morphed_frames) do
    pixel = [w, h]
    dsum1 = [0.0, 0.0]
    dsum2 = [0.0, 0.0]
    weightsum = 0

    {width, height, _} = Nx.shape(src_image)

    a = 0.2
    b = 1.25
    m = 0.1

    Enum.map(0..(div(length(interpolated_p), 2)), fn line ->
      p = Enum.at(interpolated_p, line)
      [x_p, y_p] = p
      p1 = src_image[line]
      p2 = dest_image[line]
      q = Enum.at(interpolated_q, line)
      [x_q, y_q] = q
      q1 = src_image[line]
      q2 = dest_image[line]

      IO.inspect pixel

      u = calculate_dot(subtract(pixel, p), subtract(q, p)) / :math.pow(calculate_norm(subtract(q, p)), 2)

      v = calculate_dot(subtract(pixel, p), perpendicular(subtract(q, p))) / calculate_norm(subtract(q, p))

      x_prime1 = add(add(p1, scale_vector(subtract(q1, p1), u)), scale_vector(perpendicular(subtract(q1, p1)), v)/calculate_norm(subtract(q1, p1)))

      x_prime2 = add(add(p2, scale_vector(subtract(q2, p2), u)), scale_vector(perpendicular(subtract(q2, p2)), v)/calculate_norm(subtract(q2, p2)))

      displacement1 = subtract(x_prime1, pixel)

      displacement2 = subtract(x_prime2, pixel)

      shortest_dist =
      if u >= 1 do
        calculate_norm(subtract(q, pixel))
      else
        if u <= 0 do
          calculate_norm(subtract(p, pixel))
        else
          :math.pow(:math.pow(v, 2), 0.5)
        end
      end

      line_weight = :math.pow(:math.pow(calculate_norm(subtract(p, q)), m) / (a + shortest_dist), b)

      dsum1 = add(dsum1, scale_vector(displacement1, line_weight))

      dsum2 = add(dsum2, scale_vector(displacement2, line_weight))

      weightsum = weightsum + line_weight

      end)

      x_prime1 = add(pixel, scale_vector(dsum1, 1/weightsum))

      x_prime2 = add(pixel, scale_vector(dsum2, 1/weightsum))

      src_x = :math.floor(x_prime1[0])

      src_y = :math.floor(x_prime1[1])

      dest_x = :math.floor(x_prime2[0])

      dest_y = :math.floor(x_prime2[1])

      src_rgb =
        if src_x in 0..(width-1) and src_y in 0..(height-1), do: src_image[src_x][src_y],
        else: src_image[w][h]

      dest_rgb =
        if dest_x in 0..(width-1) and dest_y in 0..(height-1), do: dest_image[dest_x][dest_y],
        else: dest_image[w][h]

      w_i2 = (2 * (frame + 1) * (1 / (num_morphed_frames + 1)))

      w_i1 = (2 - w_i2)

      r = ((w_i1 * src_rgb[0]) + (w_i2 * dest_rgb[0])) / 2

      g = ((w_i1 * src_rgb[1]) + (w_i2 * dest_rgb[1])) / 2

      b = ((w_i1 * src_rgb[2]) + (w_i2 * dest_rgb[2])) / 2

    #   u = ((Enum.at(pixel, 0) - x_p) * (Enum.at(q, 0) - Enum.at(p, 0)) + (Enum.at(pixel, 1) - y_p) * ((Enum.at(q, 1) - Enum.at(p, 1)))) / ((Enum.at(q, 0) - Enum.at(p, 0)) * (Enum.at(q, 0) - Enum.at(p, 0)) + (Enum.at(q, 1) - Enum.at(p, 1)) * (Enum.at(q, 1) - Enum.at(p, 1)))
    #   v = ((Enum.at(pixel, 0) - x_p) * (Enum.at(p, 1) - Enum.at(q, 1)) + (Enum.at(pixel, 1) - y_p) * ((Enum.at(q, 0) - Enum.at(p, 0)))) / :math.pow((Enum.at(q, 0) - Enum.at(p, 0)) * (Enum.at(q, 0) - Enum.at(p, 0)) + (Enum.at(q, 1) - Enum.at(p, 1)) * (Enum.at(q, 1) - Enum.at(p, 1)), 0.5)

    #   x_prime1 = [Enum.at(p1, 0) + u*(Enum.at(q1, 0) - Enum.at(p1, 0)) + v*(Enum.at(p1, 1) - Enum.at(q1, 1)) / ((Enum.at(q1, 0) - Enum.at(q1, 0)) * (Enum.at(q1, 0) - Enum.at(q1, 0)) + (Enum.at(q1, 1) - Enum.at(q1, 1)) * (Enum.at(q1, 1) - Enum.at(q1, 1))), Enum.at(pixel, 1) + u*(Enum.at(q1, 1) - Enum.at(p1, 1)) + v*(Enum.at(q1, 0) - Enum.at(p1, 0)) / ((Enum.at(q1, 0) - Enum.at(q1, 0)) * (Enum.at(q1, 0) - Enum.at(q1, 0)) + (Enum.at(q1, 1) - Enum.at(q1, 1)) * (Enum.at(q1, 1) - Enum.at(q1, 1)))]
    #   x_prime2 = [Enum.at(p2, 0) + u*(Enum.at(q2, 0) - Enum.at(p2, 0)) + v*(Enum.at(p2, 1) - Enum.at(q2, 1)) / ((Enum.at(q2, 0) - Enum.at(q2, 0)) * (Enum.at(q2, 0) - Enum.at(q2, 0)) + (Enum.at(q2, 1) - Enum.at(q2, 1)) * (Enum.at(q2, 1) - Enum.at(q2, 1))), Enum.at(pixel, 1) + u*(Enum.at(q2, 1) - Enum.at(p2, 1)) + v*(Enum.at(q2, 0) - Enum.at(p2, 0)) / ((Enum.at(q2, 0) - Enum.at(q2, 0)) * (Enum.at(q2, 0) - Enum.at(q2, 0)) + (Enum.at(q2, 1) - Enum.at(q2, 1)) * (Enum.at(q2, 1) - Enum.at(q2, 1)))]

    #   displacement1 = [Enum.at(x_prime1, 0) - Enum.at(pixel, 0), Enum.at(x_prime1, 1) - Enum.at(pixel, 1)]
    #   displacement2 = [Enum.at(x_prime2, 0) - Enum.at(pixel, 0), Enum.at(x_prime2, 1) - Enum.at(pixel, 1)]

    #   shortest_dist =
    #     if u >= 1 do
    #       :math.pow((Enum.at(q, 0) - Enum.at(pixel, 0)) * (Enum.at(q, 0) - Enum.at(pixel, 0)) + (Enum.at(q, 1) - Enum.at(pixel, 1)) * (Enum.at(q, 1) - Enum.at(pixel, 1)), 0.5)
    #     else
    #       if u <= 0 do
    #         :math.pow((Enum.at(p, 0) - Enum.at(pixel, 0)) * (Enum.at(p, 0) - Enum.at(pixel, 0)) + (Enum.at(p, 1) - Enum.at(pixel, 1)) * (Enum.at(p, 1) - Enum.at(pixel, 1)), 0.5)
    #       else
    #         :math.pow(:math.pow(v, 2), 0.5)
    #       end
    #     end

    #   line_weight = (:math.pow((x_p - x_q) * (x_p - x_q) + (y_p - y_q) * (y_p - y_q), m/2)) / :math.pow(a + shortest_dist, b)

    #   dsum1 = [Enum.at(dsum1, 0) + (line_weight * Enum.at(displacement1, 0)), Enum.at(dsum1, 1) + (line_weight * Enum.at(displacement1, 1))]
    #   dsum2 = [Enum.at(dsum2, 0) + (line_weight * Enum.at(displacement2, 0)), Enum.at(dsum2, 1) + (line_weight * Enum.at(displacement2, 1))]
    #   weightsum = weightsum + line_weight
    # end)

    # x_prime1 = [Enum.at(pixel, 0) + (Enum.at(dsum1, 0) / weightsum), Enum.at(pixel, 1) + (Enum.at(dsum1, 1) / weightsum)]
    # x_prime2 = [Enum.at(pixel, 0) + (Enum.at(dsum2, 0) / weightsum), Enum.at(pixel, 1) + (Enum.at(dsum2, 1) / weightsum)]

    # src_x = :math.floor(Enum.at(x_prime1, 0))
    # src_y = :math.floor(Enum.at(x_prime1, 1))
    # dest_x = :math.floor(Enum.at(x_prime2, 0))
    # dest_y = :math.floor(Enum.at(x_prime2, 1))

    # src_rgb =
    #   if src_x in 0..(width-1) and src_y in 0..(height-1), do: Enum.at(Enum.at(src_image, src_x), src_y),
    #   else: Enum.at(Enum.at(src_image, w), h)

    # dest_rgb =
    #   if dest_x in 0..(width-1) and dest_y in 0..(height-1), do: Enum.at(Enum.at(dest_image, dest_x), dest_y),
    #   else: Enum.at(Enum.at(dest_image, w), h)

    # w_i2 = (2 * (frame + 1) * (1 / (num_morphed_frames + 1)))
    # w_i1 = (2 - w_i2)

    # r = ((w_i1 * Enum.at(src_rgb, 0)) + (w_i2 * Enum.at(dest_rgb, 0))) / 2
    # g = ((w_i1 * Enum.at(src_rgb, 1)) + (w_i2 * Enum.at(dest_rgb, 1))) / 2
    # b = ((w_i1 * Enum.at(src_rgb, 2)) + (w_i2 * Enum.at(dest_rgb, 2))) / 2

    [r, g, b]
  end

  def process_slice(morphed_im, src_image, dest_image, interpolated_p, interpolated_q, starting, frame, num_morphed_frames) do
    {height, width, _} = Nx.shape(src_image)
    Enum.map(0..(height-1), fn h ->
      Enum.map(0..(width-1), fn w ->
        process_pixel(morphed_im, src_image, dest_image, interpolated_p, interpolated_q, {w, h+starting}, frame, num_morphed_frames)
      end)
    end)
  end
end
