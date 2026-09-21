defmodule TowerWeb.Live.Occurrences.Show do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events
  alias TowerWeb.Live.Paths

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, session, socket) do
    base_path = session["base_path"]
    occurrences_base_path = "#{base_path}/occurrences"
    issues_base_path = "#{base_path}/issues"

    case Events.get_event(id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> push_navigate(to: occurrences_base_path)

        {:ok, socket}

      event ->
        {:ok,
         assign(socket,
           event: event,
           base_path: base_path,
           occurrences_base_path: occurrences_base_path,
           issues_base_path: issues_base_path,
           show_delete_modal: false,
           reason_expanded: false
         )}
    end
  end

  @impl Phoenix.LiveView
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    {:ok, _} = Events.delete_event(socket.assigns.event)

    socket =
      socket
      |> put_flash(:info, "Event deleted successfully")
      |> push_navigate(to: socket.assigns.occurrences_base_path)

    {:noreply, socket}
  end

  def handle_event("toggle_reason", _params, socket) do
    {:noreply, assign(socket, reason_expanded: !socket.assigns.reason_expanded)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    page = params["page"] || "1"

    filters = [
      search: Map.get(params, "search", ""),
      level: Map.get(params, "level", ""),
      datetime_range: Map.get(params, "datetime_range", ""),
      datetime_range_from: Map.get(params, "datetime_range_from", ""),
      datetime_range_to: Map.get(params, "datetime_range_to", ""),
      issue_ids: Map.get(params, "issue_ids", "")
    ]

    back_path = Paths.index_path(socket.assigns.occurrences_base_path, filters, %{page: page})

    {:noreply, assign(socket, back_path: back_path)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-10 pb-10">
      <div class="flex justify-between mb-4">
        <.back_button navigate={@back_path} />
        <button
          type="button"
          phx-click="show_delete_modal"
          class="font-inter text-sm text-red-500 border border-red-500 w-24 h-8 px-2 py-1 mb-6 hover:bg-red-400/10"
        >
          Delete
        </button>
      </div>

      <.confirm_modal
        show={@show_delete_modal}
        cancel_event="cancel_delete"
        confirm_event="confirm_delete"
      />

      <div class="flex flex-col gap-1 mb-6">
        <span class="text-lg font-mono text-white">ID: #{@event.id}</span>
        <.link
          navigate={Paths.show_path(@issues_base_path, @event.similarity_id, [])}
          class="text-sm font-mono text-tower-text-secondary hover:text-white transition-colors"
        >
          Issue ID: #{@event.similarity_id}
        </.link>
      </div>

      <div class="font-mono text-white mb-8">
        <div class="text-lg line-clamp-1">{@event.normalized_reason}</div>
        <div class="mt-4">
          <.expandable_reason reason={@event.normalized_reason} expanded={@reason_expanded} />
        </div>
      </div>

      <div class="mb-8 border border-tower-line-color p-4">
        <h2 class="text-lg font-roboto-slab text-white mb-4 font-light">Stack Trace</h2>
        <pre class="text-sm font-mono text-tower-text-secondary whitespace-pre-wrap">{format_stacktrace(@event.stacktrace)}</pre>
      </div>

      <div class="mb-8 border border-tower-line-color p-4">
        <h2 class="text-lg font-roboto-slab text-white mb-4 font-light">Metadata</h2>
        <pre class="text-sm font-inter text-tower-text-secondary whitespace-pre-wrap">{format_metadata(@event.metadata)}</pre>
      </div>
    </div>
    """
  end

  defp format_stacktrace(nil), do: "No stacktrace available"
  defp format_stacktrace([]), do: "No stacktrace available"

  defp format_stacktrace(stacktrace) when is_list(stacktrace) do
    Exception.format_stacktrace(stacktrace)
  end

  defp format_stacktrace(stacktrace) do
    inspect(stacktrace, pretty: true)
  end

  defp format_metadata(nil), do: "No metadata available"
  defp format_metadata(metadata) when metadata == %{}, do: "No metadata available"

  defp format_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join("\n")
  end

  defp format_metadata(metadata) do
    inspect(metadata, pretty: true)
  end
end
