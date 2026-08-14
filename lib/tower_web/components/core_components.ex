defmodule TowerWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  alias TowerWeb.Live.Filters

  attr(:title, :string, required: true)
  attr(:subtitle, :string, default: nil)

  def page_header(assigns) do
    ~H"""
    <div class="mb-8">
      <h1 class="text-lg font-roboto-slab font-light text-white">{@title}</h1>
      <p :if={@subtitle} class="font-roboto-slab font-light text-white mt-1 text-sm">{@subtitle}</p>
    </div>
    """
  end

  attr(:navigate, :string, required: true)

  def back_button(assigns) do
    ~H"""
    <.link navigate={@navigate} class="inline-flex items-center justify-center size-12 bg-tower-level-bg mb-6">
      <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-6 hover:size-7 text-white">
        <path stroke-linecap="round" stroke-linejoin="round" d="M10.5 19.5 3 12m0 0 7.5-7.5M3 12h18" />
      </svg>
    </.link>
    """
  end

  attr(:flash, :map, required: true)

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

  attr(:search_query, :string, required: true)

  def search_filter(assigns) do
    ~H"""
    <form phx-change="search" phx-submit="search" class="w-full h-12 px-3 py-2 flex items-center gap-2 border border-tower-line-color">
      <svg class="w-6 h-6 text-tower-text-secondary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
      </svg>
      <input
        type="text"
        placeholder="Search items"
        phx-debounce="300"
        name="query"
        value={@search_query}
        class="flex-1 bg-transparent font-inter text-sm text-tower-text-secondary placeholder-tower-text-secondary outline-none"
      />
    </form>
    """
  end

  attr(:datetime_range_options, :list, required: true)
  attr(:datetime_range_param, :string, required: true)
  attr(:datetime_range_menu_open, :boolean, required: true)

  def date_range_filter(assigns) do
    ~H"""
    <div class="relative flex items-center gap-2" phx-click-away="close_datetime_menu">
      <span class="font-inter font-light text-sm text-white">Date:</span>

      <button
        type="button"
        phx-click="toggle_datetime_menu"
        class="flex items-center gap-2 bg-tower-active font-inter font-light text-sm text-white px-2 py-1 cursor-pointer whitespace-nowrap shrink-0"
      >
        {Filters.datetime_range_label(@datetime_range_param)}
        <.chevron_down_icon class="size-[16px]" />
      </button>

      <div :if={@datetime_range_menu_open} class="absolute left-0 top-full mt-1 z-10 min-w-full bg-tower-bg border border-tower-line-color">
        <button
          :for={{label, value} <- @datetime_range_options}
          type="button"
          phx-click="filter_datetime_range"
          phx-value-datetime_range={value}
          class={[
            "block w-full text-left px-2 py-1 font-inter font-light text-sm text-white cursor-pointer whitespace-nowrap",
            if(@datetime_range_param == value, do: "bg-tower-active", else: "bg-transparent hover:bg-tower-line-color")
          ]}
        >
          {label}
        </button>
      </div>
    </div>
    """
  end

  attr(:levels, :list, required: true)
  attr(:selected_level, :string, default: nil)

  def level_filter(assigns) do
    ~H"""
    <span class="font-inter font-light text-sm text-white">Level:</span>
    <div class="flex items-center gap-4">
      <button
        :for={level <- @levels}
        type="button"
        phx-click="filter_level"
        phx-value-level={level}
        class={[
          "font-inter font-light text-sm text-white border border-tower-line-color py-1 px-2 cursor-pointer capitalize",
          if(@selected_level == level, do: "bg-tower-active", else: "bg-transparent")
        ]}
      >
        {level}
      </button>
    </div>
    """
  end

  attr(:label, :string, default: "Issue ID")

  def issue_id_filter(assigns) do
    ~H"""
    <span class="font-inter font-light text-sm text-white">{@label}:</span>
    <form phx-submit="filter_issue_id" class="flex items-center">
      <input
        type="text"
        placeholder={"Type #{@label} and press Enter"}
        name="issue_id_filter"
        value=""
        class="font-inter font-light text-sm text-white placeholder-tower-text-secondary bg-transparent border border-tower-line-color py-1 px-2 outline-none w-[180px]"
      />
    </form>
    """
  end

  attr(:search_query, :string, required: true)
  attr(:selected_level, :string, default: nil)
  attr(:issue_ids_filtered, :list, default: [])
  attr(:issue_id_label, :string, default: "Issue ID")

  def active_filters_row(assigns) do
    ~H"""
    <div :if={@search_query != "" or @selected_level != nil or @issue_ids_filtered != []} class="flex items-center gap-3 h-7">
      <span class="font-inter font-light text-sm text-white">Active filters:</span>
      <div class="border-l border-tower-line-color h-full"></div>
      <div class="flex items-center gap-2">
        <.active_filter_tag :if={@search_query != ""} value={@search_query} type="search" />
        <.active_filter_tag :if={@selected_level != nil} value={@selected_level} type="level" class="capitalize" />
        <span :if={@issue_ids_filtered != []} class="font-inter font-light text-sm text-white">{@issue_id_label}:</span>
        <div :if={@issue_ids_filtered != []} class="border-l border-tower-line-color h-full"></div>
        <.active_filter_tag :for={issue_id <- @issue_ids_filtered} value={issue_id} type="issue_id" id={issue_id} />
      </div>
      <div class="border-l border-tower-line-color h-full"></div>
      <button
        type="button"
        phx-click="clear_filter"
        phx-value-type="all"
        class="font-inter font-light text-sm text-white cursor-pointer flex items-center gap-1"
      >
        Clear filter
        <.close_icon />
      </button>
    </div>
    """
  end

  attr(:value, :any, required: true)
  attr(:type, :string, required: true)
  attr(:class, :string, default: "")
  attr(:id, :string, default: nil)

  def active_filter_tag(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="clear_filter"
      phx-value-type={@type}
      phx-value-id={@id}
      class={["font-inter font-light text-sm text-white bg-tower-line-color max-w-[130px] h-7 py-1 px-2 flex items-center justify-center gap-1 cursor-pointer", @class]}
    >
      <span class="truncate">{@value}</span>
      <.close_icon />
    </button>
    """
  end

  def close_icon(assigns) do
    ~H"""
    <svg class="w-3 h-3 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end

  attr(:class, :string, default: nil)

  def chevron_down_icon(assigns) do
    ~H"""
    <svg class={@class} viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M12 15.0538L6.34625 9.4L7.4 8.34625L12 12.9463L16.6 8.34625L17.6538 9.4L12 15.0538Z" fill="white" />
    </svg>
    """
  end
end
