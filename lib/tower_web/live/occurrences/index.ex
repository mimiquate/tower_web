defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Pagination
  alias TowerWeb.Live.Paths
  alias TowerWeb.Live.Selection

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

    base_path = session["base_path"]
    IO.inspect(socket.endpoint.config(:otp_app), label: "???")

    {:ok,
     socket
     |> assign(Filters.default_assigns())
     |> assign(
       base_path: base_path,
       occurrences_base_path: "#{base_path}/occurrences",
       selected_occurrences_ids: MapSet.new(),
       show_delete_modal: false,
       host_otp_app: socket.endpoint.config(:otp_app)
     )}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    %{
      search: search,
      level: level,
      datetime_range_param: datetime_range_param,
      datetime_range_from: datetime_range_from,
      datetime_range_to: datetime_range_to,
      issue_ids: issue_ids
    } = Filters.parse_params(params)

    datetime_range =
      Filters.datetime_range(datetime_range_param, datetime_range_from, datetime_range_to)

    case Map.get(params, "page") do
      nil ->
        {:noreply,
         push_patch(socket,
           to:
             "#{socket.assigns.occurrences_base_path}#{Paths.page_path(1, search: search, level: level, datetime_range: datetime_range_param, datetime_range_from: datetime_range_from, datetime_range_to: datetime_range_to, issue_ids: issue_ids)}",
           replace: true
         )}

      page_param ->
        page = Pagination.parse_page(page_param)

        filters =
          Filters.compact_filters(
            search: search,
            level: level,
            similarity_id: issue_ids,
            datetime_range: datetime_range
          )

        per_page = Pagination.per_page()
        total_count = Events.count_events(filters: filters)
        total_pages = Pagination.total_pages(total_count, per_page)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.occurrences_base_path}#{Paths.page_path(total_pages, search: search, level: level, datetime_range: datetime_range_param, datetime_range_from: datetime_range_from, datetime_range_to: datetime_range_to, issue_ids: issue_ids)}"
           )}
        else
          offset = (page - 1) * per_page

          events = Events.list_events(limit: per_page, offset: offset, filters: filters)

          {:noreply,
           assign(socket,
             filtered_events: events,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             search_query: search,
             selected_level: level,
             issue_ids_filtered: issue_ids,
             datetime_range_param: datetime_range_param,
             datetime_range_from: datetime_range_from,
             datetime_range_to: datetime_range_to,
             datetime_range_custom_open: datetime_range_param == "custom",
             current_filters: [
               search: search,
               level: level,
               datetime_range: datetime_range_param,
               datetime_range_from: datetime_range_from,
               datetime_range_to: datetime_range_to,
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

    <.filters_panel
      search_query={@search_query}
      datetime_range_options={@datetime_range_options}
      datetime_range_param={@datetime_range_param}
      datetime_range_from={@datetime_range_from}
      datetime_range_to={@datetime_range_to}
      datetime_range_custom_open={@datetime_range_custom_open}
      datetime_range_menu_open={@datetime_range_menu_open}
      levels={@levels}
      selected_level={@selected_level}
      issue_ids_filtered={@issue_ids_filtered}
    />

    <% selected_count = MapSet.size(@selected_occurrences_ids) %>
    <% selected_item_label = Selection.item_label(selected_count) %>
    <% selected_occurrence_label = occurrence_label(selected_count) %>

    <.confirm_modal
      show={@show_delete_modal}
      title={"Delete #{selected_occurrence_label}?"}
      description={"Are you sure you want to delete #{selected_count} #{selected_occurrence_label}? This action cannot be undone."}
      cancel_event="cancel_delete_selected"
      confirm_event="delete_selected"
      confirm_label="Delete"
    />

    <.list_empty_state
      empty={@filtered_events == []}
      search_query={@search_query}
      selected_level={@selected_level}
      datetime_range_param={@datetime_range_param}
      issue_ids_filtered={@issue_ids_filtered}
      label="occurrences"
    />

    <.data_table rows={@filtered_events}>
      <:header>
        <th class="py-2 pl-2 w-8">
          <.select_all_checkbox checked={Selection.all_selected?(@filtered_events, @selected_occurrences_ids)} />
        </th>

        <th class="py-2 pl-6 text-base font-light">
          <div class="flex items-center gap-3">
            <span>Related Occurrence</span>
            <.bulk_delete_toolbar selected_count={selected_count} item_label={selected_item_label} />
          </div>
        </th>
        <th class="py-2 pl-6 text-base font-light w-[132px]">Item Level</th>
        <th class="py-2 pl-6 text-base font-light w-[180px]">Timestamp</th>
      </:header>
      <:row :let={event}>
        <td class="py-3 pl-2 w-8">
          <.row_checkbox id={event.id} checked={MapSet.member?(@selected_occurrences_ids, event.id)} />
        </td>
        <td class="py-3 pl-6 max-w-0">
          <div class="flex flex-col overflow-hidden">
            <.id_link
              id={event.id}
              navigate={
                Paths.show_path(
                  @occurrences_base_path,
                  event.id,
                  [search: @search_query, level: @selected_level, datetime_range: @datetime_range_param, datetime_range_from: @datetime_range_from, datetime_range_to: @datetime_range_to, issue_ids: @issue_ids_filtered],
                  %{page: @page}
                )
              }
            />
            <div class="flex items-start gap-3 w-full">
              <span class="text-sm text-tower-text-secondary shrink-0">#{event.similarity_id}</span>
              <span class="text-sm text-tower-text-secondary line-clamp-1 min-w-0 flex-1">{event.normalized_reason}</span>
            </div>
            <.last_stacktrace_line stacktrace={event.stacktrace} host_otp_app={@host_otp_app} />
          </div>
        </td>
        <td class="py-3 pl-6">
          <.level_badge level={event.level} />
        </td>
        <td class="py-3 pl-6">
          <.datetime_stack datetime={event.datetime} />
        </td>
      </:row>
    </.data_table>

    <.pagination
      page={@page}
      total_pages={@total_pages}
      page_path={
        &Paths.page_path(&1,
          search: @search_query,
          level: @selected_level,
          datetime_range: @datetime_range_param,
          datetime_range_from: @datetime_range_from,
          datetime_range_to: @datetime_range_to,
          issue_ids: @issue_ids_filtered
        )
      }
    />
    """
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_datetime_menu", _params, socket) do
    datetime_range_menu_open = !socket.assigns.datetime_range_menu_open

    {:noreply,
     assign(socket,
       datetime_range_menu_open: datetime_range_menu_open,
       datetime_range_custom_open:
         datetime_range_menu_open and socket.assigns.datetime_range_custom_open
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("close_datetime_menu", _params, socket) do
    {:noreply, assign(socket, datetime_range_menu_open: false, datetime_range_custom_open: false)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_custom_range", _params, socket) do
    {:noreply, assign(socket, Filters.toggle_custom_range(socket.assigns))}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_datetime_range", params, socket) do
    datetime_range_param = params["datetime_range"] || ""

    {:noreply,
     socket
     |> assign(datetime_range_menu_open: false, datetime_range_custom_open: false)
     |> push_patch(
       to:
         Paths.build_path(
           socket.assigns.occurrences_base_path,
           Filters.current_filters(socket.assigns,
             datetime_range: datetime_range_param,
             datetime_range_from: "",
             datetime_range_to: ""
           )
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_datetime_range_custom", %{"from" => from, "to" => to}, socket) do
    if Filters.datetime_range("custom", from, to) == [] do
      Process.send_after(self(), :clear_flash, 3000)

      {:noreply,
       put_flash(socket, :error, "Please enter a valid date/time (YYYY-MM-DD HH:MM:SS)")}
    else
      {:noreply,
       socket
       |> assign(datetime_range_menu_open: false, datetime_range_custom_open: false)
       |> push_patch(
         to:
           Paths.build_path(
             socket.assigns.occurrences_base_path,
             Filters.current_filters(socket.assigns,
               datetime_range: "custom",
               datetime_range_from: from,
               datetime_range_to: to
             )
           )
       )}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Paths.build_path(
           socket.assigns.occurrences_base_path,
           Filters.current_filters(socket.assigns, search: query)
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_level", %{"level" => level}, socket) do
    new_level = if socket.assigns.selected_level == level, do: nil, else: level

    {:noreply,
     push_patch(socket,
       to:
         Paths.build_path(
           socket.assigns.occurrences_base_path,
           Filters.current_filters(socket.assigns, level: new_level)
         )
     )}
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
           to:
             Paths.build_path(
               socket.assigns.occurrences_base_path,
               Filters.current_filters(socket.assigns, issue_ids: new_issue_ids)
             )
         )}

      _ ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply, put_flash(socket, :error, "Please enter a valid issue ID")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => "issue_id", "id" => id}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Paths.build_path(
           socket.assigns.occurrences_base_path,
           Filters.clear_filter(socket.assigns, "issue_id", id)
         )
     )}
  end

  def handle_event("clear_filter", %{"type" => type}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Paths.build_path(
           socket.assigns.occurrences_base_path,
           Filters.clear_filter(socket.assigns, type)
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected_occurrences_ids = Selection.toggle(socket.assigns.selected_occurrences_ids, id)

    {:noreply, assign(socket, selected_occurrences_ids: selected_occurrences_ids)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_select_all", _params, socket) do
    visible_ids = MapSet.new(socket.assigns.filtered_events, & &1.id)

    selected_occurrences_ids =
      Selection.toggle_all(socket.assigns.selected_occurrences_ids, visible_ids)

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
         "#{socket.assigns.occurrences_base_path}#{Paths.page_path(socket.assigns.page, Filters.current_filters(socket.assigns))}"
     )}
  end

  defp occurrence_label(1), do: "occurrence"
  defp occurrence_label(_count), do: "occurrences"
end
