defmodule TowerWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-lg font-roboto-slab font-light text-white">{@title}</h1>
      <p :if={@subtitle} class="font-roboto-slab font-light text-white mt-1 text-sm">{@subtitle}</p>
    </div>
    """
  end

  attr :navigate, :string, required: true

  def back_button(assigns) do
    ~H"""
    <.link navigate={@navigate} class="inline-flex items-center justify-center w-10 h-10 bg-tower-level-bg text-tower-id hover:text-white mb-6">
      <span class="text-lg">←</span>
    </.link>
    """
  end
end
