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
        {:ok,
         assign(socket,
           event: event,
           base_path: base_path,
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
      |> push_navigate(to: socket.assigns.base_path)

    {:noreply, socket}
  end

  def handle_event("toggle_reason", _params, socket) do
    {:noreply, assign(socket, reason_expanded: !socket.assigns.reason_expanded)}
  end

  @impl Phoenix.LiveView
  def handle_params(params, _uri, socket) do
    from_page = params["from_page"] || "1"
    search = Map.get(params, "search", "")
    back_path = index_path(socket.assigns.base_path, search, from_page)
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

      <div class="font-mono text-white mb-8">
        <div class="text-lg line-clamp-1">{format_reason(@event.reason)}</div>
        <div class="mt-4">
          <pre class="text-sm font-inter text-tower-text-secondary whitespace-pre-wrap">{if @reason_expanded, do: format_reason(@event.reason), else: format_reason(@event.reason, 500)}</pre>
        </div>
        <button
          :if={reason_exceeds_limit?(@event.reason, 500)}
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

  defp index_path(base_path, "", page), do: "#{base_path}?page=#{page}"

  defp index_path(base_path, search, page),
    do: "#{base_path}?#{URI.encode_query(page: page, search: search)}"
end
