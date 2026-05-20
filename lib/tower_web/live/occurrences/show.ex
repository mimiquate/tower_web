defmodule TowerWeb.Live.Occurrences.Show do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, _session, socket) do
    event = Events.get_event!(id)
    {:ok, assign(socket, event: event)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <div class="pt-6 px-10 pb-10">
      <.back_button navigate="/tower" />

      <div class="text-lg font-mono text-white mb-6">
        #{@event.id}
      </div>

      <div class="text-lg font-mono text-white mb-8">
        {format_reason(@event.reason)}
      </div>

      <div>
        <div class="mb-8 border border-tower-line-color p-4">
          <h2 class="text-lg font-tower text-white mb-4 font-light">Stack Trace</h2>
          <pre class="text-sm font-mono text-tower-text-secondary whitespace-pre-wrap">{format_stacktrace(@event.stacktrace)}</pre>
        </div>

        <div class="mb-8 border border-tower-line-color p-4">
          <h2 class="text-lg font-tower text-white mb-4 font-light">Metadata</h2>
          <pre class="text-sm font-inter text-tower-text-secondary whitespace-pre-wrap">{format_metadata(@event.metadata)}</pre>
        </div>
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
  defp format_metadata(%{}), do: "No metadata available"

  defp format_metadata(metadata) when is_map(metadata) do
    metadata
    |> Enum.map(fn {k, v} -> "#{k}: #{inspect(v)}" end)
    |> Enum.join("\n")
  end

  defp format_metadata(metadata) do
    inspect(metadata, pretty: true)
  end
end
