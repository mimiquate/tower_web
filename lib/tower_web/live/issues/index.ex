defmodule TowerWeb.Live.Issues.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Issues

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    base_path = session["base_path"]

    {:ok,
     assign(socket,
       base_path: base_path,
       issues: Issues.list_issues()
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.page_header title="Issues" subtitle="Track and manage application errors" />

    <div :if={@issues == []} class="text-gray-400">
      No issues recorded yet.
    </div>

    <table :if={@issues != []} class="w-full text-left">
      <thead class="text-tower-text-primary font-roboto-slab border-b border-tower-line-color">
        <tr>
          <th class="py-2 text-base font-light w-[68px]">Level</th>
          <th class="py-2 pl-6 text-base font-light">Reason (error message)</th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Occurrences</th>
          <th class="py-2 pl-6 text-base font-light w-[132px]">Last Seen</th>
        </tr>
      </thead>
      <tbody class="font-inter">
        <tr :for={issue <- @issues} class="border-b border-tower-line-color h-24 overflow-hidden">
          <td class="py-3">
            <span class={["bg-tower-level-bg w-[68px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", level_class(issue.last_event.level)]}>
              {issue.last_event.level}
            </span>
          </td>
          <td class="py-3 pl-6 max-w-0">
            <div class="flex items-baseline gap-3 overflow-hidden">
              <span class="text-sm text-tower-text-primary shrink-0">#{issue.similarity_id}</span>
              <span class="text-sm text-tower-text-secondary truncate">{format_reason(issue.last_event.reason)}</span>
            </div>
          </td>
          <td class="py-3 pl-6">
            <span class="text-sm text-white">{issue.count_occurrences}</span>
          </td>
          <td class="py-3 pl-6">
            <div class="flex flex-col">
              <span class="text-sm text-white">{format_date(issue.last_seen)}</span>
              <span class="text-xs text-tower-text-secondary">{format_time(issue.last_seen)}</span>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
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
end
