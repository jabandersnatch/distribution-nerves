defmodule Grupo0.Utils.Imagineer do
  def read_image(file_name) do
    case Imagineer.load(file_name) do
      {:ok, image} -> image
      {:error, error} -> error
    end
  end

  def save_image(image, file_name) do
    :ok = Imagineer.write(image, file_name)
  end
end
