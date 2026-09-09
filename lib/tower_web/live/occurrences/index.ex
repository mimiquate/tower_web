defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerWeb.Live.DatetimeFormatter
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Level
  alias TowerWeb.Live.Pagination
  alias TowerWeb.Live.Paths

  @per_page 20
  @allowed_filter_keys [:search, :level, :datetime_range, :issue_ids]

  def allowed_filter_keys, do: @allowed_filter_keys

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
       datetime_range_menu_open: false,
       selected_occurrences_ids: MapSet.new(),
       show_delete_modal: false
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> Level.validate_level()
    datetime_range_param = params["datetime_range"] || "last_7d"
    datetime_range = Filters.datetime_range(datetime_range_param)
    issue_ids = params |> Map.get("issue_ids", "") |> Filters.parse_issue_ids()

    case Map.get(params, "page") do
      nil ->
        {:noreply,
         push_patch(socket,
           to:
             "#{socket.assigns.occurrences_base_path}#{Paths.page_path(1, search: search, level: level, datetime_range: datetime_range_param, issue_ids: issue_ids)}",
           replace: true
         )}

      page_param ->
        page = Pagination.parse_page(page_param)

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

        total_pages = Pagination.total_pages(total_count, @per_page)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.occurrences_base_path}#{Paths.page_path(total_pages, search: search, level: level, datetime_range: datetime_range_param, issue_ids: issue_ids)}"
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
             levels: Level.levels(),
             datetime_range_param: datetime_range_param,
             current_filters: [
               search: search,
               level: level,
               datetime_range: datetime_range_param,
               issue_ids: issue_ids
             ]
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

    <.page_header title="Occurrences" subtitle="Track occurrences" />

    <div class="flex flex-col gap-3 mb-3">
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

    <% selected_count = MapSet.size(@selected_occurrences_ids) %>
    <% selected_item_label = item_label(selected_count) %>
    <% selected_occurrence_label = occurrence_label(selected_count) %>

    <.confirm_modal
      show={@show_delete_modal}
      title={"Delete #{selected_occurrence_label}?"}
      description={"Are you sure you want to delete #{selected_count} #{selected_occurrence_label}? This action cannot be undone."}
      cancel_event="cancel_delete_selected"
      confirm_event="delete_selected"
      confirm_label="Delete"
    />

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
          <th class="py-2 pl-2 w-8">
            <input
              type="checkbox"
              phx-click="toggle_select_all"
              checked={visible_ids_selected?(@filtered_events, @selected_occurrences_ids)}
              class="accent-tower-active [color-scheme:dark]"
            />
          </th>

          <th class="py-2 pl-6 text-base font-light">
            <div class="flex items-center gap-3">
              <span>Related Occurrence</span>
              <span :if={selected_count > 0} class="font-inter text-sm font-normal text-tower-text-secondary">
                {selected_count} {selected_item_label} selected
              </span>
              <button
                :if={selected_count > 0}
                type="button"
                phx-click="show_delete_modal"
                class="font-inter text-sm font-normal text-red-500 border border-red-500 px-2 hover:bg-red-400/10"
              >
                Delete
              </button>
            </div>
          </th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Item Level</th>
          <th class="py-2 pl-6 text-base font-light w-[180px]">Timestamp</th>
        </tr>
      </thead>
      <tbody class="font-inter">
        <tr :for={event <- @filtered_events} class="border-b border-tower-line-color h-24 overflow-hidden hover:border-b-[0.5px] hover:border-[#444] hover:bg-[rgba(74,88,120,0.15)]">
          <td class="py-3 pl-2 w-8">
            <input
              type="checkbox"
              phx-click="toggle_select"
              phx-value-id={event.id}
              checked={MapSet.member?(@selected_occurrences_ids, event.id)}
              class={[
                "accent-tower-active [color-scheme:dark]",
                MapSet.member?(@selected_occurrences_ids, event.id) && "opacity-100"
              ]}
            />
          </td>
          <td class="py-3 pl-6 max-w-0">
            <% last_stacktrace_line = last_stacktrace_line(event.stacktrace) %>
            <div class="flex flex-col overflow-hidden">
              <.link
                navigate={
                  Paths.show_path(
                    @occurrences_base_path,
                    event.id,
                    [search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered],
                    %{page: @page}
                  )
                }
                class="text-sm text-tower-text-primary transition-all cursor-pointer inline-block w-fit hover:underline"
              >
                #{event.id}
              </.link>
              <span class="text-sm text-tower-text-secondary line-clamp-1">{event.normalized_reason}</span>
              <span :if={last_stacktrace_line} class="text-xs text-tower-text-secondary/70 font-mono line-clamp-1">
                {last_stacktrace_line}
              </span>
            </div>
          </td>
          <td class="py-3 pl-6">
            <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", Level.level_class(event.level)]}>{event.level}</span>
          </td>
          <td class="py-3 pl-6">
            <div class="flex flex-col">
              <span class="text-sm text-tower-text-secondary">{DatetimeFormatter.format_date(event.datetime)}</span>
              <span class="text-xs text-tower-text-secondary">{DatetimeFormatter.format_time(event.datetime)}</span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <.pagination
      page={@page}
      total_pages={@total_pages}
      page_path={
        &Paths.page_path(&1, search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, issue_ids: @issue_ids_filtered)
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

  @impl Phoenix.LiveView
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_occurrences_ids =
      if MapSet.member?(socket.assigns.selected_occurrences_ids, id) do
        MapSet.delete(socket.assigns.selected_occurrences_ids, id)
      else
        MapSet.put(socket.assigns.selected_occurrences_ids, id)
      end

    {:noreply, assign(socket, selected_occurrences_ids: selected_occurrences_ids)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_select_all", _params, socket) do
    visible_ids = MapSet.new(socket.assigns.filtered_events, & &1.id)

    selected_occurrences_ids =
      if MapSet.subset?(visible_ids, socket.assigns.selected_occurrences_ids) do
        MapSet.difference(socket.assigns.selected_occurrences_ids, visible_ids)
      else
        MapSet.union(socket.assigns.selected_occurrences_ids, visible_ids)
      end

    {:noreply, assign(socket, selected_occurrences_ids: selected_occurrences_ids)}
  end

  @impl Phoenix.LiveView
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: true)}
  end

  @impl Phoenix.LiveView
  def handle_event("cancel_delete_selected", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false)}
  end

  @impl Phoenix.LiveView
  def handle_event("delete_selected", _params, socket) do
    ids = MapSet.to_list(socket.assigns.selected_occurrences_ids)
    {deleted_count, _} = Events.delete_events(ids)

    Process.send_after(self(), :clear_flash, 3000)

    {:noreply,
     socket
     |> assign(selected_occurrences_ids: MapSet.new(), show_delete_modal: false)
     |> put_flash(:info, "Deleted #{deleted_count} #{occurrence_label(deleted_count)}.")
     |> push_patch(
       to:
         "#{socket.assigns.occurrences_base_path}#{Paths.page_path(socket.assigns.page, current_filters(socket, []))}"
     )}
  end

  defp build_path(socket, filters) do
    Paths.index_path(socket.assigns.occurrences_base_path, filters, %{page: 1})
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

  defp visible_ids_selected?(events, selected_occurrences_ids) do
    Enum.all?(events, &MapSet.member?(selected_occurrences_ids, &1.id))
  end

  defp item_label(1), do: "item"
  defp item_label(_count), do: "items"

  defp occurrence_label(1), do: "occurrence"
  defp occurrence_label(_count), do: "occurrences"

  defp last_stacktrace_line(nil), do: nil
  defp last_stacktrace_line([]), do: nil

  defp last_stacktrace_line(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> Enum.filter(&tower_stacktrace_entry?/1)
    |> List.first()
    |> format_mfa_entry()
  end

  defp last_stacktrace_line(_stacktrace), do: nil

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    arity = if is_list(arity_or_args), do: length(arity_or_args), else: arity_or_args
    Exception.format_mfa(module, function, arity)
  end

  defp tower_stacktrace_entry?({module, _fun, _arity, _location}) when is_atom(module) do
    module |> Atom.to_string() |> String.starts_with?("Elixir.Tower")
  end

  defp tower_stacktrace_entry?(_entry), do: false
end
