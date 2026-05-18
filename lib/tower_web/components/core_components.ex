defmodule TowerWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  attr :title, :string, required: true
  attr :subtitle, :string, default: nil

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-lg font-tower font-light text-white">{@title}</h1>
      <p :if={@subtitle} class="font-tower font-light text-white mt-1 text-sm">{@subtitle}</p>
    </div>
    """
  end
end
