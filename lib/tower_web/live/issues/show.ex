defmodule TowerWeb.Live.Issues.Show do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerDB.Issues
  alias TowerWeb.Live.DatetimeFormatter
  alias TowerWeb.Live.Filters
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
          Events.list_events(
            limit: @recent_events_limit,
            filters: [similarity_id: id, datetime_range: Filters.datetime_range("last_30d")]
          )

        {:ok,
         assign(socket,
           issue: issue,
           recent_events: recent_events,
           recent_events_limit: @recent_events_limit,
           base_path: base_path,
           issues_base_path: issues_base_path,
           occurrences_base_path: "#{base_path}/occurrences",
           reason_expanded: false
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

    back_path = Paths.index_path(socket.assigns.issues_base_path, filters)
    {:noreply, assign(socket, back_path: back_path)}
  end

  @impl Phoenix.LiveView
  def handle_event("toggle_reason", _params, socket) do
    {:noreply, assign(socket, reason_expanded: !socket.assigns.reason_expanded)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-10 pb-10">
      <.back_button navigate={@back_path} />

      <div class="flex flex-col gap-3 mb-8">
        <span class="inline-flex bg-tower-active font-mono text-lg text-white px-2 w-fit">ID: #{@issue.id}</span>
        <p class="font-mono text-lg text-white line-clamp-1">{format_reason(@issue.last_event.reason)}</p>
      </div>

      <div class="border border-tower-line-color p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Description</h2>
          <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", level_class(@issue.last_event.level)]}>
            {@issue.last_event.level}
          </span>
        </div>
        <div class="mb-6">
          <pre class="text-sm font-inter text-tower-text-secondary whitespace-pre-wrap">{if @reason_expanded, do: format_reason(@issue.last_event.reason), else: format_reason(@issue.last_event.reason, 500)}</pre>
          <button
            :if={reason_exceeds_limit?(@issue.last_event.reason, 500)}
            phx-click="toggle_reason"
            class="inline-flex items-center gap-1 text-sm text-tower-text-secondary hover:text-white mt-2 transition-colors"
          >
            <span class="underline">{if @reason_expanded, do: "Show less", else: "Show more"}</span>
            <svg
              xmlns="http://www.w3.org/2000/svg"
              fill="none"
              viewBox="0 0 24 24"
              stroke-width="2"
              stroke="currentColor"
              class={["size-4 transition-transform", @reason_expanded && "rotate-180"]}
            >
              <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5" />
            </svg>
          </button>
        </div>
        <div class="flex gap-12">
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Total Occurrences</span>
            <span class="text-sm text-tower-text-secondary">{@issue.count_events}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">First Seen</span>
            <span class="text-sm text-tower-text-secondary">{DatetimeFormatter.format_date(@issue.first_seen)} {DatetimeFormatter.format_time(@issue.first_seen)}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Last Seen</span>
            <span class="text-sm text-tower-text-secondary">{DatetimeFormatter.format_date(@issue.last_seen)} {DatetimeFormatter.format_time(@issue.last_seen)}</span>
          </div>
        </div>
      </div>

      <div class="border border-tower-line-color p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Occurrences ({@issue.count_events})</h2>
          <div class="flex items-center gap-3">
            <span class="text-sm font-medium text-tower-text-secondary">Last {@recent_events_limit}</span>
            <.link
              navigate={Paths.index_path(@occurrences_base_path, [issue_ids: @issue.id, datetime_range: "last_30d"], %{page: 1})}
              class="bg-tower-line-color text-white text-sm px-2 py-1"
            >
              See more
            </.link>
          </div>
        </div>

        <div :if={@recent_events == []} class="text-gray-400">No occurrences recorded yet.</div>

        <div :for={event <- @recent_events} class="flex items-center gap-6 border-b border-tower-line-color py-2 last:border-b-0">
          <div class="flex flex-col justify-center w-[180px] shrink-0">
            <span class="text-sm text-white">{DatetimeFormatter.format_date(event.datetime)}</span>
            <span class="text-xs text-tower-text-secondary">{DatetimeFormatter.format_time(event.datetime)}</span>
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

  defp format_reason(reason, limit \\ nil)

  defp format_reason(reason, limit) when is_exception(reason) do
    Exception.format(:error, reason)
    |> maybe_truncate(limit)
  end

  defp format_reason(reason, limit) when is_binary(reason) do
    maybe_truncate(reason, limit)
  end

  defp format_reason(reason, limit) do
    reason
    |> inspect(pretty: true)
    |> maybe_truncate(limit)
  end

  defp maybe_truncate(text, nil), do: text

  defp maybe_truncate(text, max_length) do
    if String.length(text) > max_length do
      String.slice(text, 0, max_length) <> "..."
    else
      text
    end
  end

  defp reason_exceeds_limit?(reason, limit) when is_exception(reason) do
    String.length(Exception.format(:error, reason)) > limit
  end

  defp reason_exceeds_limit?(reason, limit) when is_binary(reason) do
    String.length(reason) > limit
  end

  defp reason_exceeds_limit?(reason, limit) do
    String.length(inspect(reason, pretty: true)) > limit
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
