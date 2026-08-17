defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerWeb.Live.Filters
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
       occurrences_base_path: "#{base_path}/occurrences",
       datetime_range_options: Filters.datetime_range_options(),
       datetime_range_menu_open: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> Filters.validate_level()
    datetime_range_param = params["datetime_range"] || ""
    datetime_range = Filters.datetime_range(datetime_range_param)
    issue_ids = params |> Map.get("issue_ids", "") |> Filters.parse_issue_ids()

    case Map.get(params, "page") do
      nil ->
        {:noreply,
         push_patch(socket,
           to:
             "#{socket.assigns.occurrences_base_path}#{page_path(1, search: search, level: level, datetime_range: datetime_range_param, similarity_id: issue_ids)}",
           replace: true
         )}

      page_param ->
        page = parse_page(page_param)

        total_count =
          Events.count_events(
            filters:
              Filters.compact_filters(
                search: search,
                level: level,
                similarity_id: issue_ids,
                datetime_range: datetime_range
              )
          )

        total_pages = max(ceil(total_count / @per_page), 1)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.occurrences_base_path}#{page_path(total_pages, search: search, level: level, datetime_range: datetime_range_param, issue_ids: issue_ids)}"
           )}
        else
          offset = (page - 1) * @per_page

          events =
            Events.list_events(
              limit: @per_page,
              offset: offset,
              filters:
                Filters.compact_filters(
                  search: search,
                  level: level,
                  datetime_range: datetime_range,
                  similarity_id: issue_ids
                )
            )

          {:noreply,
           assign(socket,
             filtered_events: events,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             search_query: search,
             selected_level: level,
             issue_ids_filtered: issue_ids,
             levels: Filters.levels(),
             datetime_range_param: datetime_range_param
           )}
        end
    end
  end

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
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

    <.page_header title="Occurrences" subtitle="Track occurrences" />

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

          <.issue_id_filter />
        </div>

        <.active_filters_row
          search_query={@search_query}
          selected_level={@selected_level}
          issue_ids_filtered={@issue_ids_filtered}
        />
      </div>
    </div>

    <div
      :if={
        @filtered_events == [] and
          not Filters.any_active?(search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, similarity_id: @issue_ids_filtered)
      }
      class="text-gray-400"
    >
      No occurrences recorded yet.
    </div>
    <div
      :if={
        @filtered_events == [] and
          Filters.any_active?(search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, similarity_id: @issue_ids_filtered)
      }
      class="text-gray-400"
    >
      No matching occurrences found.
    </div>

    <table :if={@filtered_events != []} class="w-full text-left">
      <thead class="text-tower-text-primary font-roboto-slab border-b border-tower-line-color">
        <tr>
          <th class="py-2 text-base font-light w-[132px]">Timestamp</th>
          <th class="py-2 text-base font-light">Related Occurrence</th>
          <th class="py-2 text-base font-light w-[132px]">Item Level</th>
        </tr>
      </thead>
      <tbody class="font-inter">
        <tr :for={event <- @filtered_events} class="border-b border-tower-line-color h-24 overflow-hidden">
          <td class="py-3">
            <div class="flex flex-col">
              <span class="text-sm text-white">{format_date(event.datetime)}</span>
              <span class="text-xs text-tower-text-secondary">{format_time(event.datetime)}</span>
            </div>
          </td>
          <td class="py-3 max-w-0">
            <div class="flex flex-col overflow-hidden">
              <.link navigate={show_path(@occurrences_base_path, event.id, [search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered], @page)} class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block">
                #{event.id}
              </.link>
              <span class="text-sm text-tower-text-secondary line-clamp-2">{format_reason(event.reason)}</span>
            </div>
          </td>
          <td class="py-3">
            <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", level_class(event.level)]}>{event.level}</span>
          </td>
        </tr>
      </tbody>
    </table>

    <div :if={@total_pages > 1} class="flex items-center justify-start gap-2 mt-6 font-inter text-sm">
      <.link
        :if={@page > 1}
        patch={page_path(@page - 1, search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered)}
        class="text-tower-text-primary hover:text-white transition-colors"
      >
        Previous
      </.link>
      <span :if={@page == 1} class="text-gray-400">
        Previous
      </span>

      <div class="flex items-center gap-2">
        <%= for item <- page_items(@page, @total_pages) do %>
          <%= if item == :ellipsis do %>
            <span class="min-w-7 h-7 px-2 flex items-center justify-center text-tower-text-primary">...</span>
          <% else %>
            <.link
              patch={page_path(item, search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered)}
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
        patch={page_path(@page + 1, search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered)}
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
       to:
         build_path(socket,
           search: socket.assigns.search_query,
           level: socket.assigns.selected_level,
           datetime_range: datetime_range_param
         )
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
    "#{socket.assigns.occurrences_base_path}#{page_path(1, filters)}"
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

  defp page_items(_current_page, total_pages) when total_pages <= 7 do
    Enum.to_list(1..total_pages)
  end

  defp page_items(current_page, total_pages) do
    cond do
      current_page <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++ [:ellipsis, total_pages]
    end
  end

  defp show_path(base_path, event_id, filters, page) do
    params = Paths.filters_to_params(%{}, filters) |> Map.put(:from_page, page)
    "#{base_path}/#{event_id}?#{URI.encode_query(params)}"
  end

  defp page_path(page, filters) do
    params = Paths.filters_to_params(%{page: page}, filters)
    "?#{URI.encode_query(params)}"
  end
end
