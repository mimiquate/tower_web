defmodule TowerWeb.Live.Occurrences do
  use TowerWeb.Web, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
