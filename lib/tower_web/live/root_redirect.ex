defmodule TowerWeb.Live.RootRedirect do
  use TowerWeb.Web, :live_view

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    {:ok, redirect(socket, to: "#{session["base_path"]}/dashboard")}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H""
  end
end
