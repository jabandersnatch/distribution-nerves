defmodule MixProject do
  use Mix.Project

  def project do
    [
      app: :imagenes,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nx, "~> 0.6"},
      {:kino, "~> 0.12.0"},
      {:ex_image_info, "~> 0.2.4"},
      {:mogrify, "~> 0.9.3"}
    ]
  end
end
