defmodule TowerWeb.Live.Dashboard.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerDB.Issues
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Paths

  @occurrences_chart_max_events 500

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    base_path = session["base_path"]

    {:ok,
     assign(socket,
       base_path: base_path,
       dashboard_base_path: "#{base_path}/dashboard",
       datetime_range_options: Filters.datetime_range_options(),
       datetime_range_menu_open: false,
       levels: Filters.levels()
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> Filters.validate_level()
    datetime_range_param = params["datetime_range"] || "last_7d"
    datetime_range = Filters.datetime_range(datetime_range_param)

    filters =
      Filters.compact_filters(
        search: search,
        level: level,
        datetime_range: datetime_range
      )

    total_occurrences = Events.count_events(filters: filters)
    show_chart = total_occurrences <= @occurrences_chart_max_events

    chart_datetimes =
      if show_chart do
        Events.list_events(
          limit: @occurrences_chart_max_events,
          filters: filters,
          select: [:datetime]
        )
        |> Enum.map(& &1.datetime)
      else
        []
      end

    {:noreply,
     assign(socket,
       total_errors: Issues.count_issues(filters: filters),
       total_occurrences: total_occurrences,
       show_chart: show_chart,
       chart_datetimes: chart_datetimes,
       chart_datetime_range: datetime_range,
       search_query: search,
       selected_level: level,
       datetime_range_param: datetime_range_param
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.page_header title="Dashboard" subtitle="Overview" />

    <div class="flex flex-col gap-3 mb-6">
      <.search_filter search_query={@search_query} />

      <div class="w-full px-3 py-2 flex flex-col gap-3 border border-tower-line-color">
        <div class="flex items-center gap-[12px]">
          <.date_range_filter
            datetime_range_options={@datetime_range_options}
            datetime_range_param={@datetime_range_param}
            datetime_range_menu_open={@datetime_range_menu_open}
          />

          <div class="border-l border-tower-line-color h-7"></div>

          <.level_filter levels={@levels} selected_level={@selected_level} />
        </div>

        <.active_filters_row search_query={@search_query} selected_level={@selected_level} />
      </div>
    </div>

    <div class="flex gap-3 items-start w-full mb-6">
      <.metric_card label="Total Errors" value={@total_errors} />
      <.metric_card label="Total Occurrences" value={@total_occurrences} />
    </div>

    <div :if={@show_chart} class="mb-6">
      <.occurrences_chart datetimes={@chart_datetimes} datetime_range={@chart_datetime_range} />
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_datetime_menu", _params, socket) do
    {:noreply, assign(socket, datetime_range_menu_open: !socket.assigns.datetime_range_menu_open)}
  end

  def handle_event("close_datetime_menu", _params, socket) do
    {:noreply, assign(socket, datetime_range_menu_open: false)}
  end

  def handle_event("filter_datetime_range", params, socket) do
    datetime_range_param = params["datetime_range"] || ""

    {:noreply,
     socket
     |> assign(datetime_range_menu_open: false)
     |> push_patch(
       to: build_path(socket, current_filters(socket, datetime_range: datetime_range_param))
     )}
  end

  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, search: query)))}
  end

  def handle_event("filter_level", %{"level" => level}, socket) do
    new_level = if socket.assigns.selected_level == level, do: nil, else: level

    {:noreply,
     push_patch(socket, to: build_path(socket, current_filters(socket, level: new_level)))}
  end

  def handle_event("clear_filter", %{"type" => type}, socket) do
    filters =
      case type do
        "all" -> [search: "", level: nil, datetime_range: ""]
        "search" -> current_filters(socket, search: "")
        "level" -> current_filters(socket, level: nil)
      end

    {:noreply, push_patch(socket, to: build_path(socket, filters))}
  end

  defp build_path(socket, filters) do
    params = Paths.filters_to_params(%{}, filters)
    "#{socket.assigns.dashboard_base_path}?#{URI.encode_query(params)}"
  end

  defp current_filters(socket, overrides) do
    [
      search: socket.assigns.search_query,
      level: socket.assigns.selected_level,
      datetime_range: socket.assigns.datetime_range_param
    ]
    |> Keyword.merge(overrides)
  end

  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)

  defp metric_card(assigns) do
    ~H"""
    <div class="flex-1 box-border flex flex-col gap-3 p-6 border border-tower-line-color">
      <p class="font-light font-roboto-slab text-white text-lg leading-6 tracking-[-0.15px]">{@label}</p>
      <p class="font-light font-roboto-slab text-white text-lg leading-6 tracking-[-0.15px]">{@value}</p>
    </div>
    """
  end
end
