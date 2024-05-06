defmodule ContadorPalabras.Trabajador do
  def count(palabras) do
    IO.inspect(palabras, label: "Fragmento de texto recibido por el nodo")
    resultado = palabras
                |> Enum.map(&String.downcase/1)  # Normalizar a minúsculas
                |> Enum.reduce(%{}, fn palabra, acc ->
                   Map.update(acc, palabra, 1, &(&1 + 1))
                 end)
    IO.inspect(resultado, label: "Envío del conteo de palabras al nodo servidor")
    {:ok, resultado}
  end
end
