defmodule TowerWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :tower_web,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:tower_db, path: "../tower_db"},
      {:phoenix_live_view, "~> 1.1"},
      {:postgrex, ">= 0.0.0", only: :test},
      {:tower, "~> 0.8"},
      {:plug, "~> 1.16"},
      {:phoenix, "~> 1.7", optional: true},
      {:phoenix_html, "~> 4.0", optional: true},
      {:phoenix_live_view, "~> 1.0", optional: true}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
