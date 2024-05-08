defmodule A6.MixProject do
  use Mix.Project

  def project do
    [
      app: :a6,
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
      {:mogrify, "~> 0.8.0"},
      {:pngex, "~> 0.1.2"},
      {:image, "~> 0.37"},
       {:nx, "~> 0.4"},

    ]
  end

end
