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

  @doc """
  Returns the absolute URL of the occurrence with the given id in the dashboard.

  Requires the URL where the host application mounts the dashboard:

      config :tower_web, base_url: "https://myapp.com/tower"

  Raises when `base_url` is not configured.
  """
  @spec occurrence_url(String.t()) :: String.t()
  def occurrence_url(id) do
    "#{base_url()}/occurrences/#{id}"
  end

  defp base_url do
    :tower_web |> Application.fetch_env!(:base_url) |> String.trim_trailing("/")
  end
end
