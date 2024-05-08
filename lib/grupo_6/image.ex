defmodule Image do
  alias :math, as: Math
  @cores System.schedulers_online()
  @moduledoc """
  Documentation for `Image`.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Image.read_image("image/P1.png") |> IO.inspect()

  """
  def read_image(file_name) do
    case Imagineer.load(file_name) do
      {:ok, image} -> image
      {:error, error} -> error
    end
  end

  def rotate(img, angle) when angle > 90 do
    n = div(round(angle), 90)
    rest = angle - n * 90
    img = Enum.reduce(1..n, img, fn _, acc -> rotate(acc, 90) end)
    rotate(img, rest)
  end

  def rotate(img, angle) do
    {pixels, width, height} = {img.pixels, img.width, img.height}
    default_pixel = List.to_tuple(pixels |> Enum.at(0) |> Enum.at(0) |> Tuple.to_list |> Enum.map(fn _ -> 0 end))
    angle_rad = angle * Math.pi() / 180

    new_w = width * abs(Math.cos(angle_rad)) + height * abs(Math.sin(angle_rad)) |> round()
    new_h = height * abs(Math.cos(angle_rad)) + width * abs(Math.sin(angle_rad)) |> round()

    alpha = - abs(Math.tan(angle_rad / 2))
    beta = - abs(Math.sin(angle_rad))

    first_shear = xshear(pixels, alpha, width, height, default_pixel) |> Matrix.reflect() |> Matrix.transpose()
    {width, height} = {length(Enum.at(first_shear, 0)), length(first_shear)}
    # IO.puts("1st shear successful with width #{width} and height #{height}")

    second_shear = xshear(first_shear, beta, width, height, default_pixel) |> Matrix.transpose() |> Matrix.reflect()
    {width, height} = {length(Enum.at(second_shear, 0)), length(second_shear)}
    # IO.puts("2nd shear successful with width #{width} and height #{height}")

    third_shear = xshear(second_shear, alpha, width, height, default_pixel)
    {width, height} = {length(Enum.at(third_shear, 0)), length(third_shear)}
    # IO.puts("3rd shear successful with width #{width} and height #{height}")

    diff_w = div(width - new_w, 2)
    diff_h = div(height - new_h, 2)

    third_shear = third_shear
      |> Enum.drop(diff_h)
      |> Enum.drop(- diff_h)
      |> Enum.map(fn row ->
        row |> Enum.drop(diff_w) |> Enum.drop(-diff_w)
      end)

    {width, height} = {length(Enum.at(third_shear, 0)), length(third_shear)}

    img = %{img | width: width}
    img = %{img | height: height}
    %{img | pixels: third_shear}
  end

  def xshear(pixels, shear, width, height, default_pixel) do
    new_width = ((width + abs(shear * (height + 0.5))) |> floor())
    diff = (new_width - width)
    Agent.start(fn -> (for _ <- 1..(height), do: List.duplicate(default_pixel, new_width)) end, name: Img)
    width = width - 1

    Enum.chunk_every(0..(height - 1), div(height, @cores)) |> Enum.map(fn chunk -> Task.async(fn ->
      Enum.each(chunk, fn y ->
        skew = shear * (y + 0.5)
        skew_i = floor(skew)
        skew_f = skew - skew_i
        oleft = Enum.reduce(0..(width - 1), default_pixel, fn x, acc ->
          pixel = Matrix.index(pixels, y, width - x) |> to_list()
          left = for i <- pixel, do: round(i * skew_f)
          pixel = Matrix.sub(pixel, left) |> Matrix.add(acc |> to_list) |> List.to_tuple()

          Agent.update(Img, fn state -> Matrix.update(state, y, width - x + skew_i - 1 + diff, pixel) end)
          left |> List.to_tuple()
        end)
        Agent.update(Img, fn state -> Matrix.update(state, y, skew_i + diff, oleft) end)
      end)
    end) end) |> Enum.map(&Task.await/1)

    # |> Enum.map(fn list_i -> Task.async(fn -> list_count(list_i) end) end)

    ans = Agent.get(Img, & &1)
    Agent.stop(Img)
    ans
  end

  defp to_list(x) do
    cond do
      is_list(x) -> x
      is_tuple(x) -> Tuple.to_list(x)
      true -> {:error, "Wrong type"}
    end
  end

  def morph(img1, img2) do

    {width, height} = {img1.width, img1.height}

    default_pixel = List.to_tuple(img1.pixels |> Enum.at(0) |> Enum.at(0) |> Tuple.to_list |> Enum.map(fn _ -> 0 end))

    a_w = 1
    p_w = 1
    b_w = 1

    lines1 = [[{0, 0}, {length(Enum.at(img1.pixels, 0))-1, length(img1.pixels)-1}],
            [{length(img1.pixels)-1, 0}, {length(Enum.at(img1.pixels, 0))-1, 0}]]

    lines2 = [[{0, 0}, {length(Enum.at(img1.pixels, 0))-1, length(img1.pixels)-1}],
            [{length(img1.pixels)-1, 0}, {length(Enum.at(img1.pixels, 0))-1, 0}]]

    Agent.start(fn -> img2.pixels end, name: Img)


    Enum.each(0..(height - 1), fn y ->
       Enum.reduce(0..(width - 1), default_pixel, fn x, acc ->
        dsum = {0, 0}
        weightsum = 0
        answer = Enum.map(0..(length(lines1)-1), fn l ->
          pq = Enum.at(lines2, l)
          pi_qi = Enum.at(lines1, l)
          {p, q} = {Enum.at(pq, 0), Enum.at(pq, 1)}
          {pi, qi} = {Enum.at(pi_qi, 0), Enum.at(pi_qi, 1)}

          x_p = {x - elem(p, 0), y - elem(p, 1)}
          q_p = {elem(q, 0) - elem(p, 0), elem(q, 1) - elem(p, 1)}

          norm_qp = norm(q_p)
          qp_or = {-elem(q_p, 1), elem(q_p, 0)}

          qi_pi = {elem(qi, 0) - elem(pi, 0), elem(qi, 1) - elem(pi, 1)}
          qpi_or = {-elem(qi_pi, 1), elem(qi_pi, 0)}

          u = dot(x_p, q_p)/norm(q_p)*norm(q_p)
          v = dot(x_p, qp_or)/norm(q_p)

          u_qi_pi = {elem(qi_pi, 0)*u, elem(qi_pi, 1)*u}
          new_v = {elem(qpi_or, 0)*v/norm(qi_pi), elem(qpi_or, 1)*v/norm(qi_pi)}
          m = {elem(u_qi_pi, 0) + elem(new_v, 0), elem(u_qi_pi, 1) + elem(new_v, 1)}

          new_x = {round(elem(pi, 0) + elem(m, 0)), round(elem(pi, 1) + elem(m, 0))}

          q_x = {x - elem(qi_pi, 0), y - elem(qi_pi, 1)}

          dist = dist(u, v, x, y, p, q)
          d_i = {elem(new_x, 0) - x, elem(new_x, 1) - y}
          f_pow = Math.pow(norm(qi_pi), p_w)
          weight = Math.pow(f_pow/(a_w+dist), b_w)
          dsum = {round(elem(dsum, 0) + elem(d_i, 0)*weight), round(elem(dsum, 1) + elem(d_i, 1)*weight)}
          weightsum = weight + weightsum
          {dsum, weightsum}
        end)
        f_answer = Enum.at(answer, length(answer)-1)
        dsum_f = elem(f_answer, 0)
        weightsum_f = elem(f_answer, 1)
        final_x = {round((x + elem(dsum_f, 0))/weightsum_f), round((y + elem(dsum_f, 1))/weightsum_f)}
        IO.puts("#{inspect(final_x)}")
       end)
    end)
  end

  def dist(u, v, x, y, p, q) do
    cond do
      u >= 1 -> norm({elem(q, 0) - x, elem(q, 1) - y})
      u <= 0 -> norm({elem(p, 0) - x, elem(p, 1) - y})
      true -> abs(v)
    end
  end

  def dot(a, b) do
    elem(a, 0)*elem(b, 0) + elem(b, 1)*elem(a, 1)
  end

  def norm(a) do
    Math.sqrt(elem(a, 0)*elem(a, 0) + elem(a, 1)*elem(a, 1))
  end

  def main do
    im = read_image("images/liverpool2.png")
    im
      |> rotate(45)
      |> Imagineer.write("images/bench_test.png")
  end
end

defmodule Matrix do
  def sub(a, b) do
    Enum.zip(a, b) |> Enum.map(fn {a, b} -> a - b end)
  end

  def add(a, b) do
    Enum.zip(a, b) |> Enum.map(fn {a, b} -> a + b end)
  end

  def transpose(matrix) do
    {w, h} = {length(Enum.at(matrix, 0)), length(matrix)}
    for i <- 0..(w - 1) do
      for j <- 0..(h - 1) do
        Enum.at(matrix, j) |> Enum.at(i)
      end
    end
  end

  def reflect(matrix) do
    {w, h} = {length(Enum.at(matrix, 0)), length(matrix)}
    for i <- 0..(h - 1) do
      for j <- (w - 1)..0 do
        Enum.at(matrix, i) |> Enum.at(j)
      end
    end
  end

  def index(matrix, row, column) do
    matrix |> Enum.at(row) |> Enum.at(column)
  end

  def update(matrix, row, column, value) do
    updated_row = Enum.at(matrix, row) |> List.replace_at(column, value)
    List.replace_at(matrix, row, updated_row)
  end
end
