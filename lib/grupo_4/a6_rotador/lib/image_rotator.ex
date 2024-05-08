defmodule ImageRotator do
  require Image

  def test1 do
    rotate_image("./cat.png", "./cat_rotated.png", 2*(:math.pi/3), 1)
  end
  def test4 do
    rotate_image("./cat.png", "./cat_rotated.png", 2*(:math.pi/3), 4)
  end
  def test8 do
    rotate_image("./cat.png", "./cat_rotated.png", 2*(:math.pi/3), 8)
  end
  def test16 do
    rotate_image("./cat.png", "./cat_rotated.png", 2*(:math.pi/3), 16)
  end

  def test_all do
    #warm up
    IO.puts "Warming up"
    Enum.each(1..5, fn _ -> test1() end)

    #test 1
    {time1, _} = :timer.tc(fn -> test1() end)
    IO.puts "Time for 1 chunk: #{time1 / 1000} milliseconds"

    #test 4
    {time4, _} = :timer.tc(fn -> test4() end)
    IO.puts "Time for 4 chunks: #{time4 / 1000} milliseconds"

    #test 8
    {time8, _} = :timer.tc(fn -> test8() end)
    IO.puts "Time for 8 chunks: #{time8 / 1000} milliseconds"

    #test 16
    {time16, _} = :timer.tc(fn -> test16() end)
    IO.puts "Time for 16 chunks: #{time16 / 1000} milliseconds"

    #test 32
    {time32, _} = :timer.tc(fn -> rotate_image("./cat.png", "./cat_rotated.png", 2*(:math.pi/3), 32) end)
    IO.puts "Time for 32 chunks: #{time32 / 1000} milliseconds"

  end

  def rotate_image(input_path, output_path, angle, num_chunks) do
    input_path
    |> Image.open!
    |> Image.to_nx
    |> elem(1)
    |> rotate_matrix(angle, num_chunks)
    |> Image.from_nx
    |> elem(1)
    |> Image.write(output_path, png: [progressive: true, icc_profile: :srgb])
  end

  def calc_rotation(x,y,mid_row, mid_col, angle) do
    x1 = ((x-mid_col) * :math.cos(angle)) - ((y-mid_row) * :math.sin(angle))
    y1 = ((x-mid_col) * :math.sin(angle)) + ((y-mid_row) * :math.cos(angle))
    x1 = x1+mid_col
    y1 = y1+mid_row
    {Kernel.round(x1), Kernel.round(y1)}
  end

  def calc_pixel_color(j,i,mid_row, mid_col, width, height, angle_inverse, tensor) do
    {x1, y1} = calc_rotation(j,i, mid_row, mid_col, angle_inverse)
    # IO.inspect {x1, y1}
    if x1 < 0 or y1 < 0 or x1 > width-1 or y1 > height-1 do
      [0,0,0]
    else
      colors = tensor[y1][x1]
      colors = Nx.to_flat_list(tensor[Kernel.round(y1)][Kernel.round(x1)])
      # IO.inspect colors
      colors
    end
  end

  def rotate_matrix(tensor, angle, num_chunks) do
    {height, width, _} = Nx.shape(tensor)
    mid_row = Kernel.round(height / 2)
    mid_col = Kernel.round(width / 2)
    angle_inverse = (2*:math.pi)-angle

    #slice the height into chunks in order to parallelize
    chunk_size = Kernel.round(height / num_chunks)+1

    chunks = for i <- 0..num_chunks-1 do
      if i == num_chunks-1 do
        {i*chunk_size, height}
      else
        {i*chunk_size, ((i+1)*chunk_size) -1}
      end
    end

    Enum.map(chunks, fn chunk -> Task.async(fn -> for_chunk(chunk, mid_row, mid_col, width, height, angle_inverse, tensor) end) end)
    |> Enum.map(&Task.await/1)
    |> join_chunks
    |> Nx.tensor([type: :u8, names: [:height, :width, :bands]])
  end

  def for_chunk({chunk_start, chunk_end}, mid_row, mid_col, width, height, angle_inverse, tensor) do
    for y <- chunk_start..chunk_end do
      for x <- 1..width do
        calc_pixel_color(x,y,mid_row, mid_col,width, height, angle_inverse, tensor)
      end
    end
  end

  def join_chunks(chunks) do
    Enum.reduce(chunks, [], fn chunk, acc -> acc ++ chunk end)
  end

end
