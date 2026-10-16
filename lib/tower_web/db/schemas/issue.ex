defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias TowerWeb.DB.Event

  schema "tower_web_issues" do
    field(:count_events, :integer, virtual: true)
    field(:state, Ecto.Enum, values: [:unresolved, :resolved], default: :unresolved)

    has_one(:first_event, Event, foreign_key: :issue_id)
    has_one(:last_event, Event, foreign_key: :issue_id)

    has_many(:occurrences, Event, foreign_key: :issue_id)
  end

  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [:state])
    |> validate_required([:state])
  end

  def first_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, asc: e.datetime)
  end

  def last_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, desc: e.datetime)
  end
end
