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

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    page_param = Map.get(params, "page", "1")
    search = Map.get(params, "search", "")
    page = parse_page(page_param)
    total_count = Events.count_events(filters: [search: search])
    total_pages = max(ceil(total_count / @per_page), 1)

    if page > total_pages and total_pages > 0 do
      {:noreply, push_patch(socket, to: "#{socket.assigns.base_path}?page=#{total_pages}")}
    else
      offset = (page - 1) * @per_page
      events = Events.list_events(limit: @per_page, offset: offset, filters: [search: search])

      {:noreply,
       assign(socket,
         filtered_events: events,
         page: page,
         total_pages: total_pages,
         total_count: total_count,
         search_query: search
       )}
    end
  end

  defp parse_page(nil), do: 1
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

    <form phx-change="search" phx-submit="search" class="w-full h-12 px-3 py-2 flex items-center gap-2 border border-tower-line-color mb-4">
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
              <.link navigate={show_path(@base_path, event.id, @search_query, @page)} class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block">
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
        patch={page_path(@page - 1, @search_query)}
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
              patch={page_path(item, @search_query)}
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
        patch={page_path(@page + 1, @search_query)}
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
  def handle_event("search", %{"query" => query}, socket) do
    path =
      if query == "" do
        socket.assigns.base_path
      else
        "#{socket.assigns.base_path}?#{URI.encode_query(search: query)}"
      end

    {:noreply, push_patch(socket, to: path)}
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

  defp show_path(base_path, id, "", page), do: "#{base_path}/#{id}?from_page=#{page}"
  defp show_path(base_path, id, search, page), do: "#{base_path}/#{id}?#{URI.encode_query(from_page: page, search: search)}"

  defp page_path(page, ""), do: "?page=#{page}"
  defp page_path(page, search), do: "?#{URI.encode_query(page: page, search: search)}"
end
