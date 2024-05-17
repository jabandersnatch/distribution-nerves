defmodule Grupo0.Utils.LoadWords do
  def read_file(full_path) do
    {status, content} = File.read(full_path)

    if status == :ok do
      content
    else
      IO.puts("Failed to read file: #{status}")
    end
  end
end
