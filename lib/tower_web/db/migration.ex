defmodule TowerWeb.DB.Migration do
  @moduledoc """
  Migration module for TowerWeb.DB.

  ## Usage

  To use migrations in your application you'll need to generate an `Ecto.Migration` that wraps
  calls to `TowerWeb.DB.Migration`:

      mix ecto.gen.migration add_tower_web_db

  Open the generated migration in your editor and call the `up` and `down` functions on
  `TowerWeb.DB.Migration`:

      defmodule MyApp.Repo.Migrations.AddTowerWebDB do
        use Ecto.Migration

        def up, do: TowerWeb.DB.Migration.up(from: 0, to: 9)
        def down, do: TowerWeb.DB.Migration.down(from: 9, to: 0)
      end
  """

  use Ecto.Migration

  @spec up(keyword()) :: :ok
  def up(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    migrate(:up, (from + 1)..to//1)
  end

  @spec down(keyword()) :: :ok
  def down(opts) do
    from = Keyword.fetch!(opts, :from)
    to = Keyword.fetch!(opts, :to)

    migrate(:down, from..(to + 1)//-1)
  end

  defp migrate(direction, range) do
    for index <- range do
      pad_idx = String.pad_leading(to_string(index), 2, "0")

      [__MODULE__, "V#{pad_idx}"]
      |> Module.concat()
      |> apply(direction, [])
    end

    :ok
  end
end
