defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events

  @per_page 20

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

    {:ok, assign(socket, base_path: session["base_path"])}
  end

  @levels [:emergency, :alert, :critical, :error, :warning, :notice, :info]

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    search = Map.get(params, "search", "")
    level = params |> Map.get("level", "") |> parse_level()
    id_filters = params |> Map.get("ids", "") |> parse_id_filters()

    case Map.get(params, "page") do
      nil ->
        {:noreply, push_patch(socket, to: "#{socket.assigns.base_path}#{page_path(1, search: search, level: level, ids: id_filters)}", replace: true)}

      page_param ->
        page = parse_page(page_param)
        total_count = Events.count_events(filters: [search: search, level: level])
        total_pages = max(ceil(total_count / @per_page), 1)

        if page > total_pages and total_pages > 0 do
          {:noreply, push_patch(socket, to: "#{socket.assigns.base_path}#{page_path(total_pages, search: search, level: level)}")}
        else
          offset = (page - 1) * @per_page
          events = Events.list_events(limit: @per_page, offset: offset, filters: [search: search, level: level, ids: id_filters])

          {:noreply,
           assign(socket,
             filtered_events: events,
             page: page,
             total_pages: total_pages,
             total_count: total_count,
             search_query: search,
             selected_level: level,
             levels: @levels,
             id_filters: id_filters
           )}
        end
    end
  end

  defp parse_page(nil), do: 1
  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_id_filters(""), do: []
  defp parse_id_filters(ids_string) do
    ids_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  defp parse_level(""), do: nil

  defp parse_level(level) when is_binary(level) do
    level_atom = String.to_existing_atom(level)
    if level_atom in @levels, do: level_atom, else: nil
  rescue
    ArgumentError -> nil
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
          <div class="border-l border-tower-line-color h-6"></div>
          <form phx-submit="filter_id" class="flex items-center gap-2">
            <span class="font-inter font-light text-sm text-white">ID:</span>
            <input
              type="text"
              placeholder="Type ID and press Enter"
              name="id_filter"
              value=""
              class="w-52 bg-transparent font-inter text-sm text-tower-text-secondary placeholder-tower-text-secondary outline-none border border-tower-line-color py-1 px-2"
            />
          </form>
        </div>

        <div :if={@search_query != "" or @selected_level != nil or @id_filters != []} class="flex items-center gap-3 h-7">
          <span class="font-inter font-light text-sm text-white">Active filters:</span>
          <div :if={@search_query != "" or @selected_level != nil} class="border-l border-tower-line-color h-full"></div>
          <div :if={@search_query != "" or @selected_level != nil} class="flex items-center gap-2">
            <.active_filter_tag :if={@search_query != ""} value={@search_query} type="search" />
            <.active_filter_tag :if={@selected_level != nil} value={@selected_level} type="level" class="capitalize" />
          </div>
          <div :if={@id_filters != []} class="border-l border-tower-line-color h-full"></div>
          <div :if={@id_filters != []} class="flex items-center gap-3">
            <span class="font-inter font-light text-sm text-white">ID:</span>
            <.active_filter_tag :for={id <- @id_filters} value={id} type="id" id={id} />
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

    <div :if={@filtered_events == []} class="text-gray-400">
      No occurrences recorded yet.
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
              <.link navigate={show_path(@base_path, event.id, [search: @search_query, level: @selected_level, ids: @id_filters], @page)} class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block">
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
        patch={page_path(@page - 1, search: @search_query, level: @selected_level)}
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
              patch={page_path(item, search: @search_query, level: @selected_level)}
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
        patch={page_path(@page + 1, search: @search_query, level: @selected_level)}
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

  attr :value, :any, required: true
  attr :type, :string, required: true
  attr :class, :string, default: ""
  attr :id, :string, default: nil

  defp active_filter_tag(assigns) do
    ~H"""
    <div class="relative group">
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
      <div class="hidden group-hover:block absolute bottom-full left-1/2 -translate-x-1/2 mb-1 px-2 py-1 bg-zinc-800 text-white text-xs whitespace-nowrap z-10">
        {@value}
      </div>
    </div>
    """
  end

  @impl Phoenix.LiveView
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, search: query)))}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_level", %{"level" => level}, socket) do
    level = String.to_existing_atom(level)
    new_level = if socket.assigns.selected_level == level, do: nil, else: level

    {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, level: new_level)))}
  end

  @impl Phoenix.LiveView
  def handle_event("filter_id", %{"id_filter" => ""}, socket) do
    {:noreply, socket}
  end

  def handle_event("filter_id", %{"id_filter" => id}, socket) do
    case Integer.parse(id) do
      {_id_int, ""} ->
        current_ids = socket.assigns.id_filters
        new_ids = if id in current_ids, do: current_ids, else: current_ids ++ [id]
        {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, ids: new_ids)))}

      _ ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply, put_flash(socket, :error, "Please enter a valid number")}
    end
  end

  def handle_event("clear_filter", %{"type" => "id", "id" => id_to_remove}, socket) do
    new_ids = Enum.reject(socket.assigns.id_filters, &(&1 == id_to_remove))
    {:noreply, push_patch(socket, to: build_path(socket, current_filters(socket, ids: new_ids)))}
  end

  def handle_event("clear_filter", %{"type" => type}, socket) do
    filters =
      case type do
        "all" -> [search: "", level: nil, ids: []]
        "search" -> current_filters(socket, search: "")
        "level" -> current_filters(socket, level: nil)
      end

    {:noreply, push_patch(socket, to: build_path(socket, filters))}
  end

  defp current_filters(socket, overrides) do
    [search: socket.assigns.search_query, level: socket.assigns.selected_level, ids: socket.assigns.id_filters]
    |> Keyword.merge(overrides)
  end

  defp build_path(socket, filters) when is_list(filters) do
    params =
      filters
      |> Enum.reduce(%{page: 1}, fn
        {_key, nil}, acc -> acc
        {_key, ""}, acc -> acc
        {:ids, []}, acc -> acc
        {:ids, ids}, acc -> Map.put(acc, :ids, Enum.join(ids, ","))
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    "#{socket.assigns.base_path}?#{URI.encode_query(params)}"
  end

  defp format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%I:%M:%S %p %Z")
  end

  defp format_reason(reason) when is_exception(reason) do
    Exception.message(reason)
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
        [1, :ellipsis] ++ Enum.to_list((current_page - 1)..(current_page + 1)) ++ [:ellipsis, total_pages]
    end
  end

  defp show_path(base_path, event_id, filters, page) do
    params =
      Enum.reduce(filters, %{}, fn
        {_key, nil}, acc -> acc
        {_key, ""}, acc -> acc
        {:id, []}, acc -> acc
        {:id, ids}, acc -> Map.put(acc, :ids, Enum.join(ids, ","))
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    if params == %{} do
      "#{base_path}/#{event_id}?from_page=#{page}"
    else
      "#{base_path}/#{event_id}?#{URI.encode_query(Map.put(params, :from_page, page))}"
    end
  end

  defp page_path(page, filters) do
    params =
      filters
      |> Enum.reduce(%{page: page}, fn
        {_key, nil}, acc -> acc
        {_key, ""}, acc -> acc
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    "?#{URI.encode_query(params)}"
  end
end
