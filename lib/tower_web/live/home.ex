defmodule TowerWeb.Live.Home do
  use TowerWeb.Web, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    """
  end
end
