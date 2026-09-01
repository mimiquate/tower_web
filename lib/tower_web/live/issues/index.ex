defmodule TowerWeb.Live.Issues.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Issues
  alias TowerWeb.Live.DatetimeFormatter
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Pagination
  alias TowerWeb.Live.Paths

  @per_page 20

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

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
    datetime_range_param = params["datetime_range"] || "last_7d"
    datetime_range = Filters.datetime_range(datetime_range_param)
    issue_ids = params |> Map.get("issue_ids", "") |> Filters.parse_issue_ids()

    case Map.get(params, "page") do
      nil ->
        {:noreply,
         push_patch(socket,
           to:
             "#{socket.assigns.issues_base_path}#{Paths.page_path(1, search: search, level: level, datetime_range: datetime_range_param, issue_ids: issue_ids)}",
           replace: true
         )}

      page_param ->
        page = Pagination.parse_page(page_param)

        filters =
          Filters.compact_filters(
            search: search,
            level: level,
            datetime_range: datetime_range,
            similarity_id: issue_ids
          )

        total_count = Issues.count_issues(filters: filters)
        total_pages = Pagination.total_pages(total_count, @per_page)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.issues_base_path}#{Paths.page_path(total_pages, search: search, level: level, datetime_range: datetime_range_param, issue_ids: issue_ids)}"
           )}
        else
          offset = (page - 1) * @per_page

          issues = Issues.list_issues(limit: @per_page, offset: offset, filters: filters)

          {:noreply,
           assign(socket,
             issues: issues,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             issue_ids_filtered: issue_ids,
             search_query: search,
             selected_level: level,
             datetime_range_param: datetime_range_param
           )}
        end
    end
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <.page_header title="Issues" subtitle="Track and manage application errors" />

    <div class="flex flex-col gap-3 mb-4">
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

          <div class="border-l border-tower-line-color h-full"></div>

          <.issue_id_filter label="ID" />
        </div>

        <.active_filters_row
          search_query={@search_query}
          selected_level={@selected_level}
          issue_ids_filtered={@issue_ids_filtered}
          issue_id_label="ID"
        />
      </div>
    </div>

    <div
      :if={@issues == [] and not Filters.any_active?(search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, id: @issue_ids_filtered)}
      class="text-gray-400"
    >
      No issues recorded yet.
    </div>
    <div
      :if={@issues == [] and Filters.any_active?(search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, id: @issue_ids_filtered)}
      class="text-gray-400"
    >
      No matching issues found.
    </div>

    <table :if={@issues != []} class="w-full text-left">
      <thead class="text-tower-text-primary font-roboto-slab border-b border-tower-line-color">
        <tr>
          <th class="py-2 text-base font-light w-[68px]">Level</th>
          <th class="py-2 pl-6 text-base font-light">Reason (error message)</th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Occurrences</th>
          <th class="py-2 pl-6 text-base font-light w-[180px]">Last Seen</th>
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
              <.link
                navigate={
                  Paths.show_path(
                    @issues_base_path,
                    issue.id,
                    [
                      search: @search_query,
                      level: @selected_level,
                      datetime_range: @datetime_range_param,
                      issue_ids: @issue_ids_filtered
                    ],
                    %{page: @page}
                  )
                }
                class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block"
              >
                #{issue.id}
              </.link>
              <span class="text-sm text-tower-text-secondary truncate">{format_reason(issue.last_event.reason)}</span>
            </div>
          </td>
          <td class="py-3 pl-6">
            <span class="text-sm text-white">{issue.count_events}</span>
          </td>
          <td class="py-3 pl-6">
            <div class="flex flex-col">
              <span class="text-sm text-white">{DatetimeFormatter.format_date(issue.last_seen)}</span>
              <span class="text-xs text-tower-text-secondary">{DatetimeFormatter.format_time(issue.last_seen)}</span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <.pagination
      page={@page}
      total_pages={@total_pages}
      page_path={
        &Paths.page_path(&1, search: @search_query, level: @selected_level, datetime_range: @datetime_range_param)
      }
    />
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
  def handle_event("filter_issue_id", %{"issue_id_filter" => issue_id}, socket) do
    case Integer.parse(issue_id) do
      {_issue_id_int, ""} ->
        current_issue_ids = socket.assigns.issue_ids_filtered

        new_issue_ids =
          if issue_id in current_issue_ids,
            do: current_issue_ids,
            else: current_issue_ids ++ [issue_id]

        {:noreply,
         push_patch(socket,
           to: build_path(socket, current_filters(socket, issue_ids: new_issue_ids))
         )}

      _ ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply, put_flash(socket, :error, "Please enter a valid issue ID")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => "issue_id", "id" => issue_id_to_remove}, socket) do
    new_issue_ids = Enum.reject(socket.assigns.issue_ids_filtered, &(&1 == issue_id_to_remove))

    {:noreply,
     push_patch(socket, to: build_path(socket, current_filters(socket, issue_ids: new_issue_ids)))}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => type}, socket) do
    datetime_range_filter = [datetime_range: socket.assigns.datetime_range_param]

    filters =
      case type do
        "all" -> [search: "", level: nil, datetime_range: "", issue_ids: []]
        "search" -> current_filters(socket, search: "") ++ datetime_range_filter
        "level" -> current_filters(socket, level: nil) ++ datetime_range_filter
      end

    {:noreply, push_patch(socket, to: build_path(socket, filters))}
  end

  defp build_path(socket, filters) do
    Paths.index_path(socket.assigns.issues_base_path, filters)
  end

  defp current_filters(socket, overrides) do
    [
      search: socket.assigns.search_query,
      level: socket.assigns.selected_level,
      issue_ids: socket.assigns.issue_ids_filtered,
      datetime_range: socket.assigns.datetime_range_param
    ]
    |> Keyword.merge(overrides)
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
