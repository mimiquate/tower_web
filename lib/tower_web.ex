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

  require Logger

  defmacro __using__(which) do
    quote do
      use TowerWeb.Web, unquote(which)
    end
  end

  @doc """
  Returns the absolute URL of the occurrence with the given id in the dashboard.

  Requires the host application's endpoint and the router where
  `tower_dashboard` is mounted:

      config :tower_web,
        endpoint: MyAppWeb.Endpoint,
        router: MyAppWeb.Router

  The dashboard's path is read from the router, including any enclosing `scope`.

  Returns `nil` when either of them is not configured, or while storage is
  disabled (see `TowerWeb.DB.disable/0`), since events aren't persisted then.
  Also returns `nil`, logging a warning, when the router doesn't mount the dashboard.
  """
  @spec occurrence_url(String.t()) :: String.t() | nil
  def occurrence_url(id) do
    with true <- Application.get_env(:tower_web, :enabled, true),
         {:ok, endpoint} <- Application.fetch_env(:tower_web, :endpoint),
         {:ok, router} <- Application.fetch_env(:tower_web, :router),
         {:ok, route} <- occurrence_route(router) do
      endpoint.url() <> endpoint.path(String.replace(route, ":id", id))
    else
      _ -> nil
    end
  end

  # Finds the occurrence route that tower_dashboard mounted in the host router
  defp occurrence_route(router) do
    router
    |> Phoenix.Router.routes()
    |> Enum.find(
      &(&1.plug == Phoenix.LiveView.Plug and
          String.ends_with?(&1.path, TowerWeb.Router.occurrence_route()))
    )
    |> case do
      %{path: route} ->
        {:ok, route}

      nil ->
        Logger.warning(
          "#{inspect(router)} doesn't mount tower_dashboard, can't build occurrence URLs"
        )

        :error
    end
  end
end
