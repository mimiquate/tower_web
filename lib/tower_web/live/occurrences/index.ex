defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerWeb.Live.Occurrences.Paths

  @per_page 20

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

    base_path = session["base_path"]

    {:ok, assign(socket, base_path: base_path, occurrences_base_path: "#{base_path}/occurrences")}
  end

  @levels ~w(emergency alert critical error warning notice info)

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> validate_level()
    issue_id = Map.get(params, "issue_id", "")

    case Map.get(params, "page") do
      nil ->
        {:noreply,
         push_patch(socket,
           to:
             "#{socket.assigns.occurrences_base_path}#{page_path(1, search: search, level: level, issue_id: issue_id)}",
           replace: true
         )}

      page_param ->
        page = parse_page(page_param)

        total_count =
          Events.count_events(
            filters: [search: search, level: level, similarity_id: parse_similarity_id(issue_id)]
          )

        total_pages = max(ceil(total_count / @per_page), 1)

        if page > total_pages do
          {:noreply,
           push_patch(socket,
             to:
               "#{socket.assigns.occurrences_base_path}#{page_path(total_pages, search: search, level: level, issue_id: issue_id)}"
           )}
        else
          offset = (page - 1) * @per_page

          events =
            Events.list_events(
              limit: @per_page,
              offset: offset,
              filters: [
                search: search,
                level: level,
                similarity_id: parse_similarity_id(issue_id)
              ]
            )

          {:noreply,
           assign(socket,
             filtered_events: events,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             search_query: search,
             selected_level: level,
             issue_id_query: issue_id,
             levels: @levels
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

  defp validate_level(level) when level in @levels, do: level
  defp validate_level(_level), do: nil

  defp parse_similarity_id(""), do: nil

  defp parse_similarity_id(issue_id) do
    case Integer.parse(issue_id) do
      {num, ""} -> num
      _ -> nil
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

      <div class="w-full px-3 py-2 flex flex-col gap-3 border border-tower-line-color">
        <div class="flex items-center gap-2">
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

          <div class="border-l border-tower-line-color h-full"></div>

          <span class="font-inter font-light text-sm text-white">Issue ID:</span>
          <form phx-submit="filter_issue_id" class="flex items-center">
            <input
              type="text"
              placeholder="Type ID and press Enter"
              name="issue_id"
              value={@issue_id_query}
              class="font-inter font-light text-sm text-white placeholder-tower-text-secondary bg-transparent border border-tower-line-color py-1 px-2 outline-none w-[220px]"
            />
          </form>
        </div>

        <div :if={@search_query != "" or @selected_level != nil or @issue_id_query != ""} class="flex items-center gap-3 h-7">
          <span class="font-inter font-light text-sm text-white">Active filters:</span>
          <div class="border-l border-tower-line-color h-full"></div>
          <div class="flex items-center gap-2">
            <.active_filter_tag :if={@search_query != ""} value={@search_query} type="search" />
            <.active_filter_tag :if={@selected_level != nil} value={@selected_level} type="level" class="capitalize" />
            <.active_filter_tag :if={@issue_id_query != ""} value={@issue_id_query} type="issue_id" />
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
      </div>
    </div>

    <div :if={@filtered_events == [] and @search_query == ""} class="text-gray-400">
      No occurrences recorded yet.
    </div>
    <div :if={@filtered_events == [] and @search_query != ""} class="text-gray-400">
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
              <.link navigate={show_path(@occurrences_base_path, event.id, [search: @search_query, level: @selected_level, issue_id: @issue_id_query], @page)} class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block">
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
        patch={page_path(@page - 1, search: @search_query, level: @selected_level, issue_id: @issue_id_query)}
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
              patch={page_path(item, search: @search_query, level: @selected_level, issue_id: @issue_id_query)}
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
        patch={page_path(@page + 1, search: @search_query, level: @selected_level, issue_id: @issue_id_query)}
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

  defp close_icon(assigns) do
    ~H"""
    <svg class="w-3 h-3 flex-shrink-0" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
    </svg>
    """
  end

  attr(:value, :any, required: true)
  attr(:type, :string, required: true)
  attr(:class, :string, default: "")

  defp active_filter_tag(assigns) do
    ~H"""
    <button
      type="button"
      phx-click="clear_filter"
      phx-value-type={@type}
      class={["font-inter font-light text-sm text-white bg-tower-line-color max-w-[130px] h-7 py-1 px-2 flex items-center justify-center gap-1 cursor-pointer", @class]}
    >
      <span class="truncate">{@value}</span>
      <.close_icon />
    </button>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     push_patch(socket,
       to:
         build_path(socket,
           search: query,
           level: socket.assigns.selected_level,
           issue_id: socket.assigns.issue_id_query
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_level", %{"level" => level}, socket) do
    new_level = if socket.assigns.selected_level == level, do: nil, else: level

    {:noreply,
     push_patch(socket,
       to:
         build_path(socket,
           search: socket.assigns.search_query,
           level: new_level,
           issue_id: socket.assigns.issue_id_query
         )
     )}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_issue_id", %{"issue_id" => issue_id}, socket) do
    case Integer.parse(issue_id) do
      {_id_int, ""} ->
        {:noreply,
         push_patch(socket,
           to:
             build_path(socket,
               search: socket.assigns.search_query,
               level: socket.assigns.selected_level,
               issue_id: issue_id
             )
         )}

      _ ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply, put_flash(socket, :error, "Please enter a valid number")}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("clear_filter", %{"type" => type}, socket) do
    filters =
      case type do
        "all" ->
          [search: "", level: nil, issue_id: ""]

        "search" ->
          [
            search: "",
            level: socket.assigns.selected_level,
            issue_id: socket.assigns.issue_id_query
          ]

        "level" ->
          [
            search: socket.assigns.search_query,
            level: nil,
            issue_id: socket.assigns.issue_id_query
          ]

        "issue_id" ->
          [
            search: socket.assigns.search_query,
            level: socket.assigns.selected_level,
            issue_id: ""
          ]
      end

    {:noreply, push_patch(socket, to: build_path(socket, filters))}
  end

  defp build_path(socket, filters) do
    "#{socket.assigns.occurrences_base_path}#{page_path(1, filters)}"
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
