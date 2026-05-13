defmodule TowerWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-2xl font-tower font-light text-white">{@title}</h1>
      <p :if={@subtitle} class="font-tower font-light  text-gray-400 mt-1">{@subtitle}</p>
    </div>
    """
  end
end
