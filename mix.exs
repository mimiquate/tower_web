defmodule TowerWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :tower_web,
      description: "Phoenix LiveView dashboard for browsing Tower error events",
      version: "0.5.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      package: package()
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
      {:tower_db, "~> 0.7"},
      {:phoenix_live_view, "~> 1.1"}
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{}
    ]
  end
end
