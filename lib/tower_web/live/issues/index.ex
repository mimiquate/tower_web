defmodule TowerWeb.Live.Issues.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Issues
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Paths

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    base_path = session["base_path"]

    {:ok,
     assign(socket,
       base_path: base_path,
       issues_base_path: "#{base_path}/issues",
       datetime_range_options: Filters.datetime_range_options(),
       datetime_range_menu_open: false,
       levels: Filters.levels()
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> Filters.validate_level()
    datetime_range_param = params["datetime_range"] || ""
    datetime_range = Filters.datetime_range(datetime_range_param)

    issues =
      Issues.list_issues(
        filters:
          Filters.compact_filters(
            search: search,
            level: level,
            datetime_range: datetime_range
          )
      )

    {:noreply,
     assign(socket,
       issues: issues,
       search_query: search,
       selected_level: level,
       datetime_range_param: datetime_range_param
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.page_header title="Issues" subtitle="Track and manage application errors" />

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

    <div :if={@issues == [] and @search_query == ""} class="text-gray-400">
      No issues recorded yet.
    </div>
    <div :if={@issues == [] and @search_query != ""} class="text-gray-400">
      No matching issues found.
    </div>

    <table :if={@issues != []} class="w-full text-left">
      <thead class="text-tower-text-primary font-roboto-slab border-b border-tower-line-color">
        <tr>
          <th class="py-2 text-base font-light w-[68px]">Level</th>
          <th class="py-2 pl-6 text-base font-light">Reason (error message)</th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Occurrences</th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Last Seen</th>
        </tr>
      </thead>
      <tbody class="font-inter">
        <tr :for={issue <- @issues} class="border-b border-tower-line-color h-24 overflow-hidden">
          <td class="py-3">
            <span class={["bg-tower-level-bg w-[68px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", level_class(issue.last_event.level)]}>
              {issue.last_event.level}
            </span>
          </td>
          <td class="py-3 pl-6 max-w-0">
            <div class="flex items-baseline gap-3 overflow-hidden">
              <span class="text-sm text-tower-text-primary shrink-0">#{issue.similarity_id}</span>
              <span class="text-sm text-tower-text-secondary truncate">{format_reason(issue.last_event.reason)}</span>
            </div>
          </td>
          <td class="py-3 pl-6">
            <span class="text-sm text-white">{issue.count_occurrences}</span>
          </td>
          <td class="py-3 pl-6">
            <div class="flex flex-col">
              <span class="text-sm text-white">{format_date(issue.last_seen)}</span>
              <span class="text-xs text-tower-text-secondary">{format_time(issue.last_seen)}</span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_datetime_menu", _params, socket) do
    {:noreply, assign(socket, datetime_range_menu_open: !socket.assigns.datetime_range_menu_open)}
  end

  @impl Phoenix.LiveView
  def handle_event("close_datetime_menu", _params, socket) do
    {:noreply, assign(socket, datetime_range_menu_open: false)}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_datetime_range", params, socket) do
    datetime_range_param = params["datetime_range"] || ""

    {:noreply,
     socket
     |> assign(datetime_range_menu_open: false)
     |> push_patch(
       to: build_path(socket, current_filters(socket, datetime_range: datetime_range_param))
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, search: query)))}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_level", %{"level" => level}, socket) do
    new_level = if socket.assigns.selected_level == level, do: nil, else: level

    {:noreply,
     push_patch(socket, to: build_path(socket, current_filters(socket, level: new_level)))}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => type}, socket) do
    datetime_range_filter = [datetime_range: socket.assigns.datetime_range_param]

    filters =
      case type do
        "all" -> [search: "", level: nil, datetime_range: ""]
        "search" -> current_filters(socket, search: "") ++ datetime_range_filter
        "level" -> current_filters(socket, level: nil) ++ datetime_range_filter
      end

    {:noreply, push_patch(socket, to: build_path(socket, filters))}
  end

  defp build_path(socket, filters) do
    params = Paths.filters_to_params(%{}, filters)
    "#{socket.assigns.issues_base_path}?#{URI.encode_query(params)}"
  end

  defp current_filters(socket, overrides) do
    [
      search: socket.assigns.search_query,
      level: socket.assigns.selected_level,
      datetime_range: socket.assigns.datetime_range_param
    ]
    |> Keyword.merge(overrides)
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M:%S %p %Z")
  end

  defp format_reason(reason) when is_exception(reason) do
    Exception.format(:error, reason)
  end

  defp format_reason(reason) when is_binary(reason) do
    reason
  end

  defp format_reason(reason) do
    inspect(reason)
  end

  defp level_class(level) when level in [:error, :alert, :emergency] do
    "text-red-400"
  end

  defp level_class(level) when level in [:warning, :notice] do
    "text-yellow-400"
  end

  defp level_class(_level) do
    "text-gray-400"
  end
end
