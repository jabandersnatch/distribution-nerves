defmodule ImageRotator do
  require Mogrify

  def rotate_image(input_path, output_path, angle) do
    input_path
    |> Mogrify.open()
    |> Mogrify.custom("rotate", Integer.to_string(angle))
    |> Mogrify.save(path: output_path)
  end
end
