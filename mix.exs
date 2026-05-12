defmodule TowerWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :tower_web,
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

  defp deps do
    [
      {:tower_db, path: "../tower_db"},
      {:phoenix_live_view, "~> 1.0"}
    ]
  end
end
