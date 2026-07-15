defmodule TowerWeb.Live.Occurrences.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events

  @per_page 20

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    if connected?(socket) do
      Process.send_after(self(), :clear_flash, 3000)
    end

    {:ok, assign(socket, base_path: session["base_path"], database_unavailable: false)}
  end

  @impl Phoenix.LiveView
  def handle_params(%{"page" => page_param}, _uri, socket) do
    page = parse_page(page_param)

    with {:ok, total_count} <- Events.count_events(),
         total_pages = max(ceil(total_count / @per_page), 1),
         :ok <- if(page <= total_pages, do: :ok, else: {:redirect, total_pages}),
         offset = (page - 1) * @per_page,
         {:ok, events} <- Events.list_events(limit: @per_page, offset: offset) do
      {:noreply,
       assign(socket,
         events: events,
         page: page,
         total_pages: total_pages,
         total_count: total_count,
         database_unavailable: false
       )}
    else
      {:error, :database_unavailable} ->
        {:noreply,
         assign(socket,
           events: [],
           page: 1,
           total_pages: 1,
           total_count: 0,
           database_unavailable: true
         )}

      {:redirect, total_pages} ->
        {:noreply, push_patch(socket, to: "#{socket.assigns.base_path}?page=#{total_pages}")}
    end
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, push_patch(socket, to: "#{socket.assigns.base_path}?page=1")}
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

    <div :if={@database_unavailable} class="w-full bg-neutral-800 rounded-lg p-12 flex flex-col items-center justify-center min-h-[300px]">
      <div class="relative mb-6">
        <svg class="w-16 h-16 text-tower-text-secondary" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <ellipse cx="12" cy="5" rx="9" ry="3" stroke-width="1.5"/>
          <path d="M3 5v14c0 1.66 4.03 3 9 3s9-1.34 9-3V5" stroke-width="1.5"/>
          <path d="M3 12c0 1.66 4.03 3 9 3s9-1.34 9-3" stroke-width="1.5"/>
        </svg>
        <div class="absolute -bottom-1 -right-1 bg-red-500 rounded-full p-1">
          <svg class="w-3 h-3 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="3">
            <path d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </div>
      </div>
      <h2 class="text-xl font-roboto-slab text-white mb-2">Database is currently unavailable</h2>
      <p class="text-tower-text-secondary text-sm text-center max-w-md">
        Occurrences cannot be loaded because the database is unavailable. Please try again later.
      </p>
    </div>

    <div :if={@events == [] and not @database_unavailable} class="text-gray-400">
      No occurrences recorded yet.
    </div>

    <table :if={@events != [] and not @database_unavailable} class="w-full text-left">
      <thead class="text-tower-text-primary font-roboto-slab border-b border-tower-line-color">
        <tr>
          <th class="py-2 text-base font-light w-[132px]">Timestamp</th>
          <th class="py-2 text-base font-light">Related Occurrence</th>
          <th class="py-2 text-base font-light w-[132px]">Item Level</th>
        </tr>
      </thead>
      <tbody class="font-inter">
        <tr :for={event <- @events} class="border-b border-tower-line-color h-24 overflow-hidden">
          <td class="py-3">
            <div class="flex flex-col">
              <span class="text-sm text-white">{format_date(event.datetime)}</span>
              <span class="text-xs text-tower-text-secondary">{format_time(event.datetime)}</span>
            </div>
          </td>
          <td class="py-3 max-w-0">
            <div class="flex flex-col overflow-hidden">
              <.link navigate={"#{@base_path}/#{event.id}?from_page=#{@page}"} class="text-sm text-tower-text-primary hover:text-white hover:text-base transition-all cursor-pointer inline-block">
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
        patch={"?page=#{@page - 1}"}
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
              patch={"?page=#{item}"}
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
        patch={"?page=#{@page + 1}"}
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
end
