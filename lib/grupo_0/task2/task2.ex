defmodule Grupo0.Task2.Task2 do
  def flatten_pixels(pixels) do
    Enum.flat_map(pixels, fn row -> row end)
  end

  def prepare_tensor_data(flat_pixels, height, width) do
    # Flatten the list of RGB tuples and normalize pixel values
    flat_pixels =
      flat_pixels
      |> Enum.flat_map(fn {r, g, b} -> [r, g, b] end)

    # Create the tensor from the flat list of pixel values
    tensor = Nx.tensor(flat_pixels, type: {:f, 32})

    # Reshape the tensor to have dimensions corresponding to image height, width, and color channels
    Nx.reshape(tensor, {height, width, 3}, names: [:y, :x, :c])
  end

  def rotate_image_segment({matrix, angle, start_row, end_row}) do
    rotation_matrix =
      Nx.transpose(
        Nx.tensor([[Math.cos(angle), -Math.sin(angle)], [Math.sin(angle), Math.cos(angle)]])
      )

    {height, width, channels} = Nx.shape(matrix)

    IO.inspect({height, width, channels})

    # Prepare a new image matrix initialized to zeros for all channels
    new_image = Nx.broadcast(0, {height, width, channels})

    pivot_point = Nx.tensor([(height - 1) / 2, (width - 1) / 2])

    Enum.reduce(start_row..end_row, new_image, fn i, acc ->
      Enum.reduce(0..(width - 1), acc, fn j, acc_inner ->
        xy_mat = Nx.subtract(Nx.tensor([i, j]), pivot_point)
        rot_mat = Nx.dot(rotation_matrix, xy_mat)

        new_position = Nx.add(rot_mat, pivot_point)

        new_x = Nx.to_number(new_position[1]) |> round()
        new_y = Nx.to_number(new_position[0]) |> round()

        if 0 <= new_x and new_x < width and 0 <= new_y and new_y < height do
          # Indexed_put to handle multiple channels
          Enum.reduce(0..(channels - 1), acc_inner, fn k, acc_channel ->
            old_pixel_value = matrix[i][j][k]
            Nx.indexed_put(acc_channel, Nx.tensor([new_y, new_x, k]), old_pixel_value)
          end)
        else
          acc_inner
        end
      end)
    end)
  end

  def distribute_image(angle) do
    fn image, n ->
      {height, width, channels} = Nx.shape(image)
      segment_height = div(height, n)

      Enum.map(0..(n - 1), fn i ->
        start_row = i * segment_height
        end_row = if i == n - 1, do: height - 1, else: start_row + segment_height - 1

        mask = Nx.broadcast(0, {height, width, channels})

        rows = Enum.to_list(start_row..end_row)
        cols = Enum.to_list(0..(width - 1))
        chs = Enum.to_list(0..(channels - 1))

        indices = for r <- rows, c <- cols, k <- chs, do: [r, c, k]
        indices_tensor = Nx.tensor(indices)
        updates = Nx.broadcast(1.0, {length(rows) * width * channels})

        mask = Nx.indexed_put(mask, indices_tensor, updates)
        matrix = Nx.multiply(image, mask)

        {matrix, angle, start_row, end_row}
      end)
    end
  end

  def parallel_rotate_image(n) do
    fn {segment_matrix, angle, start_row, end_row} ->
      {height, width, channels} = Nx.shape(segment_matrix)
      sub_segment_height = div(end_row - start_row + 1, n)

      tasks =
        for i <- 0..(n - 1) do
          sub_start_row = start_row + i * sub_segment_height
          sub_end_row = if i == n - 1, do: end_row, else: sub_start_row + sub_segment_height - 1

          mask = Nx.broadcast(0, {height, width, channels})

          rows = Enum.to_list(sub_start_row..sub_end_row)
          cols = Enum.to_list(0..(width - 1))
          chs = Enum.to_list(0..(channels - 1))

          indices = for r <- rows, c <- cols, k <- chs, do: [r, c, k]
          indices_tensor = Nx.tensor(indices)
          updates = Nx.broadcast(1.0, {length(rows) * width * channels})

          mask = Nx.indexed_put(mask, indices_tensor, updates)
          parallel_matrix = Nx.multiply(segment_matrix, mask)

          Task.async(fn ->
            rotate_image_segment({
              parallel_matrix,
              angle,
              sub_start_row,
              sub_end_row
            })
          end)
        end

      # Wait for all tasks to finish and combine the results
      Enum.map(tasks, &Task.await(&1, :infinity))
      |> Enum.reduce(Nx.broadcast(0, {height, width, channels}), &Nx.add(&2, &1))
    end
  end

  def join_images(result, value) do
    Nx.add(result, value)
  end

  def matrix_to_image(original_image, out_path) do
    fn matrix ->
      pixels =
        Nx.to_list(matrix)
        |> Enum.map(fn row ->
          Enum.map(row, fn [r, g, b] -> {round(r), round(g), round(b)} end)
        end)

      out_image = %{original_image | pixels: pixels}

      Grupo0.Utils.Imagineer.save_image(out_image, out_path)
    end
  end
end
