defmodule ImgManager do
  @doc """
  Get img file
  """
  def img_read(file) do
    content = File.open!(file)

    IO.inspect(content)
    {_, width, height, _} = ExImageInfo.info File.read!(file)
    Nx.from_binary(content, :u8)
      |> Nx.reshape({height, width, 3})
  end

  @doc """
  Given the image tensor (img_tensor) and number of nodes/process divides the task to run it in parallel
  """
  def img_partition_fun({img_tensor, angle}, n) do
    {height, width, _} = Nx.shape(img_tensor)
    # by default the image if divided vertically
    n_pixels = ceil(width / n)

    Enum.map(
      # iterate over number of nodes/process
      1..n,
      fn x ->
        # divides just j that is the responsible for columns
        j_f =
          if x * n_pixels - 1 > width do
            height
          else
            x * n_pixels - 1
          end

        # gives the start and the end of column
        %{
          j_0: (x - 1) * n_pixels,
          j_f: j_f,
          i_0: 0,
          i_f: height,
          angle: angle,
          img_height: height,
          img_width: width
        }
      end
    )
  end

  @doc """
  Main function, rotates one section the image, data of starting and ending indexs for section in data and original
  image in img_tensor
  """
  def img_processing_fun(data, par) do
    IO.puts("hola0")
    {img_tensor, _} = par
    # retrieves from dictionary
    i_0 = data[:i_0]
    i_f = data[:i_f]
    j_0 = data[:j_0]
    j_f = data[:j_f]
    # get angle
    angle = data[:angle]
    img_height = data[:img_height]
    img_width = data[:img_width]
    IO.puts("hola1")
    # creates the final tensor (rectangular section of the processed image)
    cropped_tensor_xd =
      Nx.broadcast(Nx.tensor(0, type: {:u, 8}), {i_f - i_0 + 1, j_f - j_0 + 1, 3})

    IO.puts("hola")
    # cartesian product
    indexes = for i <- i_0..i_f, j <- j_0..j_f, do: {i, j}

    # processing by each pixel within limits
    Enum.reduce(
      indexes,
      cropped_tensor_xd,
      fn val, cropped_tensor ->
        # apply transform
        {i_new, j_new} = val
        x_new = j_new
        y_new = img_height - i_new - 1

        # apply matrix transformations
        # x_old = x_new * cos(-theta) - y_new * sin(-theta)
        x_old =
          Nx.to_number(
            Nx.subtract(Nx.multiply(x_new, Nx.cos(-angle)), Nx.multiply(y_new, Nx.sin(-angle)))
          )

        # y_old = x_new * sin(-theta) + y_new * sin(-theta)
        y_old =
          Nx.to_number(
            Nx.sum(
              Nx.tensor([
                Nx.to_number(Nx.multiply(x_new, Nx.sin(-angle))),
                Nx.to_number(Nx.multiply(y_new, Nx.cos(-angle)))
              ])
            )
          )

        # round to let in space the most close pixel if not exact
        j_old = round(x_old)
        i_old = img_height - round(y_old)
        # limits respect old, if it's outside old image put black pixel
        if j_old < 0 or j_old >= img_width or i_old < 0 or i_old >= img_height do
          # red
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 0]),
              Nx.tensor(0, type: {:u, 8})
            )

          # green
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 1]),
              Nx.tensor(0, type: {:u, 8})
            )

          # blue
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 2]),
              Nx.tensor(0, type: {:u, 8})
            )
        else
          # red
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 0]),
              img_tensor[i_old][j_old][0]
            )

          # green
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 1]),
              img_tensor[i_old][j_old][1]
            )

          # blue
          cropped_tensor =
            Nx.indexed_put(
              cropped_tensor,
              Nx.tensor([i_new - i_0, j_new - j_0, 2]),
              img_tensor[i_old][j_old][2]
            )
        end
      end
    )
  end

  @doc """
  Function to merge parts in single image
  """
  def img_merge_fun(list_parts) do
    # with this single line the diferents sections are concatenated to be part of same list
    Nx.concatenate(list_parts, axis: 1)
  end

  @doc """
  The function retrieves original image to be displayed
  """
  def img_persistence_fun(result) do
    # give original tensor
    # File.write("files/img_rotated.png",result)
    result
  end

  @doc """
  Function to run in
  """
  def rotate(img, angle) do
    tensor = img_read(img)
    {elapsed_time, result} =
      :timer.tc(fn ->
        ParallelServer.execute_distributed_task(
          {tensor, angle},
          &ImgManager.img_partition_fun/2,
          &ImgManager.img_merge_fun/1,
          &ImgManager.img_persistence_fun/1,
          &ImgManager.img_processing_fun/2
        )
      end)

    IO.puts("El tiempo total de ejecución es #{elapsed_time / 1_000_000} segundos.")
    result
  end
end
