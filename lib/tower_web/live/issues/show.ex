defmodule TowerWeb.Live.Issues.Show do
  use TowerWeb.Web, :live_view

  alias TowerWeb.DB.Events
  alias TowerWeb.DB.Issue
  alias TowerWeb.DB.Issues
  alias TowerWeb.Live.DatetimeFormatter
  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Level
  alias TowerWeb.Live.Paths

  @recent_events_limit 10
  @occurrences_chart_max_events 500

  @impl Phoenix.LiveView
  def mount(%{"id" => id}, session, socket) do
    base_path = session["base_path"]
    issues_base_path = "#{base_path}/issues"

    if Filters.valid_issue_id?(id) do
      case Issues.get_issue(id, recent_occurrences_limit: @recent_events_limit) do
        nil ->
          socket =
            socket
            |> put_flash(:error, "Issue not found")
            |> push_navigate(to: issues_base_path)

          {:ok, socket}

        issue ->
          chart_datetime_range = chart_datetime_range(issue)

          show_chart = issue.count_events <= @occurrences_chart_max_events

          chart_datetimes =
            if show_chart do
              Events.list_events(
                limit: @occurrences_chart_max_events,
                filters: [issue_id: id, datetime_range: chart_datetime_range],
                select: [:datetime]
              )
              |> Enum.map(& &1.datetime)
            else
              []
            end

          {:ok,
           assign(socket,
             issue: issue,
             recent_events: issue.occurrences,
             recent_events_limit: @recent_events_limit,
             show_chart: show_chart,
             chart_datetimes: chart_datetimes,
             chart_datetime_range: chart_datetime_range,
             base_path: base_path,
             issues_base_path: issues_base_path,
             occurrences_base_path: "#{base_path}/occurrences",
             show_delete_modal: false,
             reason_expanded: false,
             dropdown_open: false,
             mute_dropdown_open: false,
             mute_custom_open: false
           )}
      end
    else
      socket =
        socket
        |> put_flash(:error, "Please enter a valid issue ID")
        |> push_navigate(to: issues_base_path)

      {:ok, socket}
    end
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

    back_path = Paths.index_path(socket.assigns.issues_base_path, filters, %{page: page})
    {:noreply, assign(socket, back_path: back_path)}
  end

  @impl Phoenix.LiveView
  def handle_event("show_delete_modal", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_delete_modal: false)}
  end

  def handle_event("confirm_delete", _params, socket) do
    {_count, _} = Issues.delete_issues_and_events([socket.assigns.issue.id])

    socket =
      socket
      |> put_flash(:info, "Issue deleted successfully")
      |> push_navigate(to: socket.assigns.issues_base_path)

    {:noreply, socket}
  end

  def handle_event("toggle_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: !socket.assigns.dropdown_open)}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, dropdown_open: false)}
  end

  def handle_event("set_issue_state", %{"state" => state}, socket)
      when state in ["resolved", "unresolved"] do
    new_state = if state == "resolved", do: :resolved, else: :unresolved
    {:ok, _issue} = Issues.update_issue(socket.assigns.issue, %{state: new_state})

    issue = %{socket.assigns.issue | state: new_state}

    {:noreply, assign(socket, issue: issue, dropdown_open: false)}
  end

  def handle_event("toggle_reason", _params, socket) do
    {:noreply, assign(socket, reason_expanded: !socket.assigns.reason_expanded)}
  end

  def handle_event("toggle_mute_dropdown", _params, socket) do
    {:noreply, assign(socket, mute_dropdown_open: !socket.assigns.mute_dropdown_open)}
  end

  def handle_event("close_mute_dropdown", _params, socket) do
    {:noreply, assign(socket, mute_dropdown_open: false, mute_custom_open: false)}
  end

  def handle_event("toggle_mute_custom", _params, socket) do
    {:noreply, assign(socket, mute_custom_open: !socket.assigns.mute_custom_open)}
  end

  def handle_event("mute_issue", %{"amount" => amount, "unit" => unit}, socket) do
    case parse_mute_duration(amount, unit) do
      {:ok, seconds} ->
        issue = mute_issue_for(socket.assigns.issue, seconds)

        {:noreply,
         assign(socket, issue: issue, mute_dropdown_open: false, mute_custom_open: false)}

      :error ->
        Process.send_after(self(), :clear_flash, 3000)
        {:noreply, put_flash(socket, :error, "Enter a valid duration")}
    end
  end

  def handle_event("unmute_issue", _params, socket) do
    {:ok, _issue} = Issues.update_issue(socket.assigns.issue, %{muted_until: nil})
    issue = %{socket.assigns.issue | muted_until: nil}

    {:noreply, assign(socket, issue: issue, mute_dropdown_open: false)}
  end

  @impl Phoenix.LiveView
  def handle_info(:clear_flash, socket) do
    {:noreply, clear_flash(socket)}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.flash_messages flash={@flash} />

    <div class="pt-6 px-10 pb-10">
      <div class="flex justify-between mb-4">
        <.back_button navigate={@back_path} />
        <div class="flex gap-2">
          <div class="relative" phx-click-away="close_mute_dropdown">
            <button
              type="button"
              phx-click="toggle_mute_dropdown"
              class="flex items-center justify-between w-[180px] h-8 px-2 font-inter text-sm font-normal whitespace-nowrap bg-tower-level-bg text-white"
            >
              <span class="flex items-center gap-2">
                <.mute_badge muted={Issue.muted?(@issue)} />
              </span>
              <.chevron_down_icon class="size-4" />
            </button>

            <div :if={@mute_dropdown_open} class="absolute z-10 right-0 w-[180px] bg-tower-bg border border-tower-line-color">
              <div :if={Issue.muted?(@issue)} class="flex flex-col gap-2 p-2">
                <span class="font-inter text-xs text-tower-text-secondary">
                  Muted until {DatetimeFormatter.format_date(@issue.muted_until)} {DatetimeFormatter.format_time(@issue.muted_until)}
                </span>
                <button
                  type="button"
                  phx-click="unmute_issue"
                  class="flex items-center gap-1 w-full text-left px-2 py-1.5 font-inter text-sm text-white whitespace-nowrap hover:bg-tower-line-color"
                >
                  <.bell_icon class="size-4" /> Unmute now
                </button>
              </div>

              <div :if={!Issue.muted?(@issue)}>
                <button
                  :for={{label, amount, unit} <- mute_duration_presets()}
                  type="button"
                  phx-click="mute_issue"
                  phx-value-amount={amount}
                  phx-value-unit={unit}
                  class="flex items-center gap-1 w-full text-left px-2 py-1.5 font-inter text-sm text-white whitespace-nowrap hover:bg-tower-line-color"
                >
                  <.bell_slash_icon class="size-4" /> {label}
                </button>

                <div class="relative">
                  <button
                    type="button"
                    phx-click="toggle_mute_custom"
                    class="flex items-center justify-between gap-2 w-full text-left px-2 py-1.5 font-inter text-sm text-white whitespace-nowrap hover:bg-tower-line-color"
                  >
                    Custom...
                    <.chevron_down_icon class={"size-[14px] -rotate-90#{if @mute_custom_open, do: " rotate-0", else: ""}"} />
                  </button>

                  <form
                    :if={@mute_custom_open}
                    novalidate
                    phx-submit="mute_issue"
                    class="absolute left-full top-0 ml-1 z-10 flex flex-col gap-3 p-3 min-w-max bg-tower-bg border border-tower-line-color"
                  >
                    <div class="flex items-end gap-2">
                      <label class="flex flex-col gap-1">
                        <span class="font-inter font-light text-xs text-tower-text-secondary">Amount</span>
                        <input
                          type="number"
                          name="amount"
                          min="1"
                          value="1"
                          class="font-inter font-light text-sm text-white bg-transparent border border-tower-line-color py-1.5 px-2 outline-none focus:border-tower-active w-[80px]"
                        />
                      </label>
                      <select
                        name="unit"
                        class="font-inter font-light text-sm text-white bg-tower-bg border border-tower-line-color py-1.5 px-2 outline-none"
                      >
                        <option value="minutes">Minutes</option>
                        <option value="hours">Hours</option>
                        <option value="days">Days</option>
                      </select>
                    </div>
                    <button type="submit" class="font-inter font-light text-sm text-white bg-tower-line-color hover:bg-tower-active py-1 px-2 cursor-pointer">
                      Apply
                    </button>
                  </form>
                </div>
              </div>
            </div>
          </div>

          <div class="relative" phx-click-away="close_dropdown">
            <button
              type="button"
              phx-click="toggle_dropdown"
              class={[
                "flex items-center justify-between w-[150px] h-8 px-2 font-inter text-sm font-normal whitespace-nowrap",
                if(@issue.state == :resolved, do: "bg-green-700 text-white", else: "bg-tower-level-bg text-white")
              ]}
            >
              <span class="flex items-center gap-2">
                <.state_badge state={@issue.state} />
              </span>
              <.chevron_down_icon class="size-4" />
            </button>

            <div :if={@dropdown_open} class="absolute z-10 w-[150px] bg-tower-bg border border-tower-line-color">
              <button
                :if={@issue.state != :resolved}
                type="button"
                phx-click="set_issue_state"
                phx-value-state="resolved"
                class="flex items-center gap-1 w-full text-left px-2 py-1.5 font-inter text-sm text-white whitespace-nowrap hover:bg-tower-line-color"
              >
                <.check_icon class="size-4" /> Mark as resolved
              </button>
              <button
                :if={@issue.state == :resolved}
                type="button"
                phx-click="set_issue_state"
                phx-value-state="unresolved"
                class="flex items-center gap-2 w-full text-left px-2 py-1.5 font-inter text-sm text-white whitespace-nowrap hover:bg-tower-line-color"
              >
                <.undo_icon class="size-4" /> Reopen issue
              </button>
            </div>
          </div>
          <.delete_button size={:lg} phx-click="show_delete_modal" />
        </div>
      </div>

      <.confirm_modal
        show={@show_delete_modal}
        title="Delete issue?"
        description="Are you sure you want to delete this issue? This action cannot be undone."
        cancel_event="cancel_delete"
        confirm_event="confirm_delete"
      />

      <div class="flex flex-col gap-3 mb-8">
        <span class="inline-flex bg-tower-active font-mono text-lg text-white px-2 w-fit">ID: #{@issue.id}</span>
        <p class="font-mono text-lg text-white line-clamp-1">{@issue.last_event.normalized_reason}</p>
      </div>

      <div class="border border-tower-line-color p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Description</h2>
          <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center", Level.level_class(@issue.last_event.level)]}>
            {@issue.last_event.level}
          </span>
        </div>
        <div class="mb-6">
          <.expandable_reason reason={@issue.last_event.normalized_reason} expanded={@reason_expanded} />
        </div>
        <div class="flex gap-12">
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Total Occurrences</span>
            <span class="text-sm text-tower-text-secondary">{@issue.count_events}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">First Seen</span>
            <span class="text-sm text-tower-text-secondary">{DatetimeFormatter.format_date(@issue.first_event.datetime)} {DatetimeFormatter.format_time(@issue.first_event.datetime)}</span>
          </div>
          <div class="flex flex-col gap-1">
            <span class="text-sm text-white">Last Seen</span>
            <span class="text-sm text-tower-text-secondary">{DatetimeFormatter.format_date(@issue.last_event.datetime)} {DatetimeFormatter.format_time(@issue.last_event.datetime)}</span>
          </div>
        </div>
      </div>

      <div :if={@show_chart} class="mb-6">
        <.occurrences_chart datetimes={@chart_datetimes} datetime_range={@chart_datetime_range} />
      </div>

      <div class="border border-tower-line-color p-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="font-roboto-slab text-lg text-white font-light">Occurrences ({@issue.count_events})</h2>
          <div class="flex items-center gap-3">
            <span class="text-sm font-medium text-tower-text-secondary">Last {@recent_events_limit}</span>
            <.link
              navigate={Paths.index_path(@occurrences_base_path, [issue_ids: @issue.id, datetime_range: "all_time"], %{page: 1})}
              class="bg-tower-line-color text-white text-sm px-2 py-1"
            >
              See all
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
            <span class="text-sm text-tower-text-secondary line-clamp-1">{event.normalized_reason}</span>
          </div>
          <span class={["bg-tower-level-bg w-[132px] h-7 px-2 py-1 text-sm inline-flex items-center justify-center shrink-0", Level.level_class(event.level)]}>
            {event.level}
          </span>
        </div>
      </div>
    </div>
    """
  end

  defp mute_duration_presets do
    [
      {"Mute for 30 minutes", 30, "minutes"},
      {"Mute for 1 hour", 1, "hours"},
      {"Mute for 24 hours", 24, "hours"},
      {"Mute for 7 days", 7, "days"}
    ]
  end

  defp mute_issue_for(issue, seconds) do
    muted_until = DateTime.add(DateTime.utc_now(), seconds, :second)
    {:ok, _issue} = Issues.update_issue(issue, %{muted_until: muted_until})
    %{issue | muted_until: muted_until}
  end

  defp parse_mute_duration(amount, unit) do
    with {amount, ""} <- Integer.parse(amount),
         true <- amount > 0,
         seconds when not is_nil(seconds) <- unit_to_seconds(amount, unit) do
      {:ok, seconds}
    else
      _ -> :error
    end
  end

  defp unit_to_seconds(amount, "minutes"), do: amount * 60
  defp unit_to_seconds(amount, "hours"), do: amount * 3600
  defp unit_to_seconds(amount, "days"), do: amount * 86_400
  defp unit_to_seconds(_amount, _unit), do: nil

  @min_chart_range_us 15 * 60 * 1_000_000
  @max_chart_range_us 30 * 24 * 60 * 60 * 1_000_000

  defp chart_datetime_range(issue) do
    diff_us = DateTime.diff(issue.last_event.datetime, issue.first_event.datetime, :microsecond)
    range_us = diff_us |> max(@min_chart_range_us) |> min(@max_chart_range_us)

    {DateTime.add(issue.last_event.datetime, -range_us, :microsecond), issue.last_event.datetime}
  end
end
