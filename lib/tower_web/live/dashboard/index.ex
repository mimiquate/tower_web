defmodule TowerWeb.Live.Dashboard.Index do
  use TowerWeb.Web, :live_view

  alias TowerDB.Events

  @impl Phoenix.LiveView
  def mount(_params, session, socket) do
    total_errors = Events.count_distinct_similarity_ids()
    total_occurrences = Events.count_events()

    {:ok,
     assign(socket,
       base_path: session["base_path"],
       total_errors: total_errors,
       total_occurrences: total_occurrences
     )}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~H"""
    <.page_header title="Dashboard" subtitle="Overview" />

    <div class="flex gap-3 items-start w-full">
      <.metric_card label="Total Errors" value={@total_errors} />
      <.metric_card label="Total Occurrences" value={@total_occurrences} />
    </div>
    """
  end

  attr(:label, :string, required: true)
  attr(:value, :integer, required: true)

  defp metric_card(assigns) do
    ~H"""
    <div class="flex-1 box-border flex flex-col gap-3 p-6 border border-tower-line-color">
      <p class="font-light font-roboto-slab text-white text-lg leading-6 tracking-[-0.15px]">{@label}</p>
      <p class="font-light font-roboto-slab text-white text-lg leading-6 tracking-[-0.15px]">{@value}</p>
    </div>
    """
  end
end
