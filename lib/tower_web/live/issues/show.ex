defmodule TowerWeb.Live.Issues.Show do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerDB.Issues
  alias TowerWeb.Live.Paths

  @recent_events_limit 10

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, session, socket) do
    base_path = session["base_path"]
    issues_base_path = "#{base_path}/issues"

    case Issues.get_issue(id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Issue not found")
          |> push_navigate(to: issues_base_path)

        {:ok, socket}

      issue ->
        recent_events =
          Events.list_events(limit: @recent_events_limit, filters: [similarity_id: id])

        {:ok,
         assign(socket,
           issue: issue,
           recent_events: recent_events,
           base_path: base_path,
           issues_base_path: issues_base_path,
           occurrences_base_path: "#{base_path}/occurrences"
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    filters = [
      search: Map.get(params, "search", ""),
      level: Map.get(params, "level", ""),
      datetime_range: Map.get(params, "datetime_range", ""),
      issue_ids: Map.get(params, "issue_ids", "")
    ]

    back_path = index_path(socket.assigns.issues_base_path, filters)
    {:noreply, assign(socket, back_path: back_path)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-10 pb-10">
      <.back_button navigate={@back_path} />

      <div class="flex flex-col gap-3 mb-8">
        <span class="inline-flex bg-tower-active font-mono text-lg text-white px-2 w-fit">ID: #{@issue.id}</span>
        <p class="font-mono text-lg text-white">{format_reason(@issue.last_event.reason)}</p>
      </div>

      <div class="border border-tower-line-color p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Description</h2>
          <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", level_class(@issue.last_event.level)]}>
            {@issue.last_event.level}
          </span>
        </div>
        <p class="text-sm text-tower-text-secondary mb-6">{format_reason(@issue.last_event.reason)}</p>
        <div class="flex gap-12">
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Total Occurrences</span>
            <span class="text-sm text-tower-text-secondary">{@issue.count_events}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">First Seen</span>
            <span class="text-sm text-tower-text-secondary">{format_date(@issue.first_seen)} {format_time(@issue.first_seen)}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Last Seen</span>
            <span class="text-sm text-tower-text-secondary">{format_date(@issue.last_seen)} {format_time(@issue.last_seen)}</span>
          </div>
        </div>
      </div>

      <div class="border border-tower-line-color p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Occurrences ({@issue.count_events})</h2>
          <.link navigate={"#{@occurrences_base_path}?issue_ids=#{@issue.id}"} class="bg-tower-line-color text-white text-sm px-2 py-1">
            See all
          </.link>
        </div>

        <div :if={@recent_events == []} class="text-gray-400">No occurrences recorded yet.</div>

        <div :for={event <- @recent_events} class="flex items-center gap-6 border-b border-tower-line-color py-2 last:border-b-0">
          <div class="flex flex-col justify-center w-[132px] shrink-0">
            <span class="text-sm text-white">{format_date(event.datetime)}</span>
            <span class="text-xs text-tower-text-secondary">{format_time(event.datetime)}</span>
          </div>
          <div class="flex flex-col justify-center flex-1 min-w-0">
            <.link navigate={"#{@occurrences_base_path}/#{event.id}"} class="text-sm text-tower-text-primary hover:text-white transition-colors truncate">
              #{event.id}
            </.link>
            <span class="text-sm text-tower-text-secondary line-clamp-1">{format_reason(event.reason)}</span>
          </div>
          <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center shrink-0", level_class(event.level)]}>
            {event.level}
          </span>
        </div>
      </div>
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

  defp index_path(base_path, filters) do
    params = Paths.filters_to_params(%{}, filters)
    "#{base_path}?#{URI.encode_query(params)}"
  end
end
