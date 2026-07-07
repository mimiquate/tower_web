defmodule TowerWeb.Live.Occurrences.Show do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, session, socket) do
    base_path = session["base_path"]

    case Events.get_event(String.to_integer(id)) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "Event not found")
          |> push_navigate(to: base_path)

        {:ok, socket}

      event ->
        {:ok, assign(socket, event: event, base_path: base_path, show_delete_modal: false)}
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
      |> push_navigate(to: socket.assigns.base_path)

    {:noreply, socket}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    from_page = params["from_page"] || "1"
    filters = [search: Map.get(params, "search", ""), level: Map.get(params, "level", ""), id: Map.get(params, "id", "")]
    back_path = index_path(socket.assigns.base_path, filters, from_page)
    {:noreply, assign(socket, back_path: back_path, from_page: from_page)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-10 pb-10">
      <div class="flex justify-between items-center mb-4">
        <.back_button navigate={@back_path} />
        <button
          phx-click="show_delete_modal"
          class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-medium"
        >
          Delete
        </button>
      </div>

      <div :if={@show_delete_modal} class="fixed inset-0 z-50 flex items-center justify-center">
        <div class="absolute inset-0 bg-black bg-opacity-50" phx-click="cancel_delete"></div>
        <div class="relative bg-tower-bg border border-tower-line-color p-6 max-w-sm">
          <h3 class="font-inter text-lg font-light text-white mb-4">Are you sure?</h3>
          <p class="font-inter text-sm font-light text-tower-text-secondary mb-6">This action cannot be undone.</p>
          <div class="flex justify-end items-center gap-3">
            <button
              phx-click="cancel_delete"
              class="px-4 py-2 bg-tower-success hover:bg-tower-success-hover text-white font-inter text-sm font-light"
            >
              No, keep it
            </button>
            <button
              phx-click="confirm_delete"
              class="px-4 py-2 bg-red-600 hover:bg-red-700 text-white font-inter text-sm font-light"
            >
              Yes, delete
            </button>
          </div>
        </div>
      </div>

      <div class="text-lg font-mono text-white mb-6">
        #{@event.id}
      </div>

      <div class="text-lg font-mono text-white mb-8">
        {format_reason(@event.reason)}
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

  defp format_reason(reason) when is_exception(reason) do
    Exception.format(:error, reason)
  end

  defp format_reason(reason) when is_binary(reason) do
    reason
  end

  defp format_reason(reason) do
    inspect(reason, pretty: true)
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

  defp index_path(base_path, filters, page) do
    params =
      filters
      |> Enum.reduce(%{page: page}, fn
        {_key, nil}, acc -> acc
        {_key, ""}, acc -> acc
        {key, value}, acc -> Map.put(acc, key, value)
      end)

    "#{base_path}?#{URI.encode_query(params)}"
  end
end
