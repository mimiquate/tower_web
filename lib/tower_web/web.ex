defmodule TowerWeb.Web do
  @moduledoc false

  def html do
    quote do
      use Phoenix.Component
      import Phoenix.Controller, only: [get_csrf_token: 0]
      unquote(html_helpers())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView, layout: {TowerWeb.Layouts, :live}
      unquote(html_helpers())
    end
  end

  def router do
    quote do
      import TowerWeb.Router
    end
  end

  defp html_helpers do
    quote do
      import TowerWeb.CoreComponents
      import Phoenix.HTML
      alias Phoenix.LiveView.JS
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
