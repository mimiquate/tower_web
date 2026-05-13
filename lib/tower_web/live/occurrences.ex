defmodule TowerWeb.Live.Occurrences do
  use TowerWeb.Web, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.page_header title="Occurrences" subtitle="Track occurrences" />

    <div class="text-gray-400">
      No occurrences recorded yet.
    </div>
    """
  end
end
