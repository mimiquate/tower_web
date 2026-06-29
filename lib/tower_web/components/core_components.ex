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

  def back_button(assigns) do
    ~H"""
    <button onclick="history.back()" class="inline-flex items-center justify-center size-12 bg-tower-level-bg mb-6">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 hover:size-7 text-white">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </button>
    """
  end

  attr :flash, :map, required: true

  def flash_messages(assigns) do
    ~H"""
    <div
      :if={Phoenix.Flash.get(@flash, :info)}
      id="flash-info"
      class="fixed top-4 right-4 max-w-sm px-4 py-3 bg-green-950 border border-green-400 rounded-lg shadow-lg text-green-300 text-sm flex items-center gap-3 cursor-pointer z-50"
      phx-click="lv:clear-flash"
      phx-value-key="info"
    >
      <svg class="w-5 h-5 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
      </svg>
      <span>{Phoenix.Flash.get(@flash, :info)}</span>
    </div>
    <div
      :if={Phoenix.Flash.get(@flash, :error)}
      id="flash-error"
      class="fixed top-4 right-4 max-w-sm px-4 py-3 bg-red-950 border border-red-400 rounded-lg shadow-lg text-red-300 text-sm flex items-center gap-3 cursor-pointer z-50"
      phx-click="lv:clear-flash"
      phx-value-key="error"
    >
      <svg class="w-5 h-5 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
      </svg>
      <span>{Phoenix.Flash.get(@flash, :error)}</span>
    </div>
    """
  end
end
