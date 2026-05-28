defmodule TowerWeb do
  @moduledoc """
  TowerWeb provides a dashboard UI for viewing Tower events stored in TowerDB.

  Mount in your Phoenix router:

      use TowerWeb.Web, :router

      scope "/" do
        pipe_through :browser
        tower_dashboard "/tower"
      end
  """

  defmacro __using__(which) do
    quote do
      use TowerWeb.Web, unquote(which)
    end
  end
end
