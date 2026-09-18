defmodule TowerWeb.Live.Issues.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Issues
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Pagination
  alias TowerWeb.Live.Paths

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

    base_path = session["base_path"]

    {:ok,
     socket
     |> assign(Filters.default_assigns())
     |> assign(
       base_path: base_path,
       issues_base_path: "#{base_path}/issues",
       datetime_range_options: Filters.datetime_range_options(),
       datetime_range_menu_open: false,
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
             "#{socket.assigns.issues_base_path}#{Paths.page_path(1, search: search, level: level, datetime_range: datetime_range_param, datetime_range_from: datetime_range_from, datetime_range_to: datetime_range_to, issue_ids: issue_ids)}",
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

        per_page = Pagination.per_page()
        total_count = Issues.count_issues(filters: filters)
        total_pages = Pagination.total_pages(total_count, per_page)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.issues_base_path}#{Paths.page_path(total_pages, search: search, level: level, datetime_range: datetime_range_param, datetime_range_from: datetime_range_from, datetime_range_to: datetime_range_to, issue_ids: issue_ids)}"
           )}
        else
          offset = (page - 1) * per_page

          issues = Issues.list_issues(limit: per_page, offset: offset, filters: filters)

          {:noreply,
           assign(socket,
             filtered_issues: issues,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             issue_ids_filtered: issue_ids,
             search_query: search,
             selected_level: level,
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

    <.page_header title="Issues" subtitle="Track and manage application errors" />

    <.filters_panel
      search_query={@search_query}
      datetime_range_options={@datetime_range_options}
      datetime_range_param={@datetime_range_param}
      datetime_range_from={@datetime_range_from}
      datetime_range_to={@datetime_range_to}
      datetime_range_menu_open={@datetime_range_menu_open}
      datetime_range_custom_open={@datetime_range_custom_open}
      levels={@levels}
      selected_level={@selected_level}
      issue_ids_filtered={@issue_ids_filtered}
      issue_id_label="ID"
    />

    <.list_empty_state
      empty={@filtered_issues == []}
      search_query={@search_query}
      selected_level={@selected_level}
      datetime_range_param={@datetime_range_param}
      issue_ids_filtered={@issue_ids_filtered}
      label="issues"
    />

    <.data_table rows={@filtered_issues}>
      <:header>
        <th class="py-2 pl-6 text-base font-light"> Reason (error message)</th>
        <th class="py-2 pl-6 text-base font-light w-[132px]">Level</th>
        <th class="py-2 pl-6 text-base font-light w-[132px]">Occurrences</th>
        <th class="py-2 pl-6 text-base font-light w-[180px]">Last Seen</th>
      </:header>
      <:row :let={issue}>
        <td class="py-3 pl-6 max-w-0">
          <div class="flex flex-col overflow-hidden">
            <.id_link
              id={issue.id}
              navigate={
                Paths.show_path(
                  @issues_base_path,
                  issue.id,
                  [
                    search: @search_query,
                    level: @selected_level,
                    datetime_range: @datetime_range_param,
                      datetime_range_from: @datetime_range_from,
                      datetime_range_to: @datetime_range_to,
                    issue_ids: @issue_ids_filtered
                  ],
                  %{page: @page}
                )
              }
            />
            <span class="text-sm text-tower-text-secondary line-clamp-1">{issue.last_event.normalized_reason}</span>
            <.last_stacktrace_line stacktrace={issue.last_event.stacktrace} host_otp_app={@host_otp_app} />
          </div>
        </td>
        <td class="py-3 pl-6">
          <.level_badge level={issue.last_event.level} />
        </td>
        <td class="py-3 pl-6">
          <span class="text-sm text-white">{issue.count_events}</span>
        </td>
        <td class="py-3 pl-6">
          <.datetime_stack datetime={issue.last_seen} />
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
           socket.assigns.issues_base_path,
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
             socket.assigns.issues_base_path,
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
           socket.assigns.issues_base_path,
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
           socket.assigns.issues_base_path,
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
               socket.assigns.issues_base_path,
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
           socket.assigns.issues_base_path,
           Filters.clear_filter(socket.assigns, "issue_id", id)
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => type}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         Paths.build_path(
           socket.assigns.issues_base_path,
           Filters.clear_filter(socket.assigns, type)
         )
     )}
  end
end
