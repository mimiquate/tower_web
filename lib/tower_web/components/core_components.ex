defmodule TowerWeb.CoreComponents do
  @moduledoc false

  use Phoenix.Component

  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Pagination

  attr(:page, :integer, required: true)
  attr(:total_pages, :integer, required: true)
  attr(:page_path, :any, required: true)

  def pagination(assigns) do
    ~H"""
    <div :if={@total_pages > 1} class="flex items-center justify-start gap-2 mt-6 font-inter text-sm">
      <.link
        :if={@page > 1}
        patch={@page_path.(@page - 1)}
        class="text-tower-text-primary hover:text-white transition-colors"
      >
        Previous
      </.link>
      <span :if={@page == 1} class="text-gray-400">
        Previous
      </span>

      <div class="flex items-center gap-2">
        <%= for item <- Pagination.page_items(@page, @total_pages) do %>
          <%= if item == :ellipsis do %>
            <span class="min-w-7 h-7 px-2 flex items-center justify-center text-tower-text-primary">...</span>
          <% else %>
            <.link
              patch={@page_path.(item)}
              class={[
                "min-w-7 h-7 px-2 flex items-center justify-center text-tower-text-primary hover:text-white transition-colors",
                item == @page && "bg-tower-active"
              ]}
            >
              {item}
            </.link>
          <% end %>
        <% end %>
      </div>

      <.link
        :if={@page < @total_pages}
        patch={@page_path.(@page + 1)}
        class="text-tower-text-primary hover:text-white transition-colors"
      >
        Next
      </.link>
      <span :if={@page >= @total_pages} class="text-gray-400">
        Next
      </span>
    </div>
    """
  end

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
    <div :if={@search_query != "" or @selected_level != nil or @issue_ids_filtered != []} class="flex flex-wrap items-center gap-x-3 gap-y-2 min-h-7">
      <span class="font-inter font-light text-sm text-white">Active filters:</span>
      <div class="border-l border-tower-line-color h-7"></div>
      <.active_filter_tag :if={@search_query != ""} value={@search_query} type="search" />
      <.active_filter_tag :if={@selected_level != nil} value={@selected_level} type="level" class="capitalize" />
      <span :if={@issue_ids_filtered != []} class="font-inter font-light text-sm text-white">{@issue_id_label}:</span>
      <div :if={@issue_ids_filtered != []} class="border-l border-tower-line-color h-7"></div>
      <.active_filter_tag :for={issue_id <- @issue_ids_filtered} value={issue_id} type="issue_id" id={issue_id} />
      <div class="border-l border-tower-line-color h-7"></div>
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

  attr(:title, :string, default: "Occurrences Over Time")
  attr(:datetimes, :list, required: true)
  attr(:datetime_range, :any, required: true)

  def occurrences_chart(assigns) do
    assigns = assign(assigns, :chart, build_chart_data(assigns.datetimes, assigns.datetime_range))

    ~H"""
    <div class="border border-tower-line-color p-4">
      <p class="font-roboto-slab text-sm text-white mb-3">{@title}</p>
      <svg viewBox={"0 0 #{@chart.width} #{@chart.height}"} class="w-full h-auto">
        <line
          :for={label <- @chart.y_labels}
          x1={@chart.plot_left}
          y1={label.y}
          x2={@chart.plot_right}
          y2={label.y}
          stroke="#444"
          stroke-dasharray="2,2"
        />
        <text :for={label <- @chart.y_labels} x={@chart.plot_left - 6} y={label.y + 3} fill="#a1a1a1" font-size="9" text-anchor="end">{label.label}</text>
        <text :for={label <- @chart.x_labels} x={label.x} y={@chart.plot_bottom + 16} fill="#a1a1a1" font-size="9" text-anchor="middle">{label.label}</text>
        <polyline points={Enum.map_join(@chart.points, " ", fn point -> "#{point.x},#{point.y}" end)} fill="none" stroke="#51a2ff" stroke-width="1" />
        <rect :for={point <- @chart.points} x={point.x - 3} y={point.y - 3} width="6" height="6" fill="#51a2ff">
          <title>{"#{point.count} occurrence#{if point.count != 1, do: "s"} — #{point.label}"}</title>
        </rect>
      </svg>
    </div>
    """
  end

  @chart_width 720
  @chart_height 260
  @chart_padding_left 36
  @chart_padding_right 24
  @chart_padding_top 12
  @chart_padding_bottom 24

  @target_buckets 10

  @nice_steps [
    60,
    300,
    900,
    1_800,
    3_600,
    10_800,
    21_600,
    43_200,
    86_400,
    172_800,
    259_200,
    604_800,
    2_592_000
  ]

  defp build_chart_data(datetimes, {from, to}) do
    step = granularity(from, to)
    grid_from = floor_to_step(from, step)
    count = bucket_count(grid_from, to, step)
    starts = bucket_starts(grid_from, count, step)
    counts = aggregate(datetimes, grid_from, step, count)
    # first point to last point, so the chart always fills the full width
    duration_us = max((count - 1) * step * 1_000_000, 1)

    plot = %{
      left: @chart_padding_left,
      right: @chart_width - @chart_padding_right,
      width: @chart_width - @chart_padding_left - @chart_padding_right,
      bottom: @chart_height - @chart_padding_bottom,
      height: @chart_height - @chart_padding_top - @chart_padding_bottom
    }

    chart_max = counts |> Enum.max() |> chart_max_value()

    x_labels = build_x_labels(starts, grid_from, duration_us, plot)
    y_labels = build_y_labels(chart_max, plot)
    points = build_points(starts, counts, grid_from, duration_us, step, chart_max, plot)

    %{
      width: @chart_width,
      height: @chart_height,
      plot_left: plot.left,
      plot_right: plot.right,
      plot_bottom: plot.bottom,
      points: points,
      x_labels: x_labels,
      y_labels: y_labels
    }
  end

  # smallest step (1m, 5m, 15m, ... 1d, 7d, 30d) that keeps the chart under ~10 buckets
  defp granularity(from, to) do
    duration = DateTime.diff(to, from, :second)

    Enum.find(@nice_steps, List.last(@nice_steps), fn step ->
      duration <= step * @target_buckets
    end)
  end

  # snaps down to the grid, e.g. 12:37 -> 12:30 for a 15-min step
  defp floor_to_step(datetime, step) do
    unix = DateTime.to_unix(datetime, :second)
    DateTime.from_unix!(div(unix, step) * step, :second)
  end

  # calculates the number of time buckets needed from grid_from to to, rounding up partial buckets.
  defp bucket_count(grid_from, to, step) do
    diff = DateTime.diff(to, grid_from, :second)
    whole = div(diff, step)
    if rem(diff, step) == 0, do: whole, else: whole + 1
  end

  # the start time of every bucket, e.g. 12:30, 12:45, 13:00, ...
  defp bucket_starts(grid_from, count, step) do
    for offset <- 0..(count - 1), do: DateTime.add(grid_from, offset * step, :second)
  end

  # counts how many events fall into each bucket
  defp aggregate(datetimes, grid_from, step, count) do
    frequencies =
      Enum.frequencies_by(datetimes, fn datetime ->
        DateTime.diff(datetime, grid_from, :second)
        |> div(step)
        |> min(count - 1)
      end)

    for index <- 0..(count - 1), do: Map.get(frequencies, index, 0)
  end

  # calculates the X-axis position and label for each time bucket.
  defp build_x_labels(bucket_starts, grid_from, duration_us, plot) do
    Enum.map(bucket_starts, fn start ->
      x = time_to_x(start, grid_from, duration_us, plot)
      %{x: Float.round(x, 2), label: axis_label(start, duration_us)}
    end)
  end

  @one_day_in_microseconds 86_400 * 1_000_000

  # axis text: just the date for multi-day ranges, just the time otherwise
  defp axis_label(datetime, duration_us) when duration_us > @one_day_in_microseconds,
    do: Calendar.strftime(datetime, "%b %d")

  defp axis_label(datetime, _duration_us), do: Calendar.strftime(datetime, "%-I:%M %p")

  # tooltip text: always show the date too when buckets are sub-day, so
  # hovering a point on a multi-day chart isn't ambiguous about which day
  defp tooltip_label(datetime, step) when step < 86_400,
    do: Calendar.strftime(datetime, "%b %d, %-I:%M %p")

  defp tooltip_label(datetime, _step), do: Calendar.strftime(datetime, "%b %d")

  defp build_y_labels(chart_max, plot) do
    for fraction <- [0.0, 0.25, 0.5, 0.75, 1.0] do
      %{
        y: Float.round(plot.bottom - fraction * plot.height, 2),
        label: round(chart_max * fraction)
      }
    end
  end

  defp build_points(bucket_starts, counts, grid_from, duration_us, step, chart_max, plot) do
    bucket_starts
    |> Enum.zip(counts)
    |> Enum.map(fn {bucket, count} ->
      x = time_to_x(bucket, grid_from, duration_us, plot)
      y = plot.bottom - count / chart_max * plot.height

      %{
        x: Float.round(x, 2),
        y: Float.round(y, 2),
        count: count,
        label: tooltip_label(bucket, step)
      }
    end)
  end

  # converts a datetime into its X position based on its relative position in the time range
  defp time_to_x(datetime, grid_from, duration_us, plot) do
    fraction = DateTime.diff(datetime, grid_from, :microsecond) / duration_us
    plot.left + fraction * plot.width
  end

  defp chart_max_value(0), do: 4

  defp chart_max_value(max_count) do
    step = if max_count <= 20, do: 4, else: 20
    ceil(max_count / step) * step
  end
end
