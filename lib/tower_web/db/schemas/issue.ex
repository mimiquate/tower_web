defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias TowerWeb.DB.Event

  @primary_key {:id, UUIDv7.Type, autogenerate: true}

  schema "tower_web_issues" do
    field(:count_events, :integer, virtual: true)
    field(:state, Ecto.Enum, values: [:unresolved, :resolved], default: :unresolved)
    field(:muted_until, :utc_datetime_usec)

    has_one(:first_event, Event, foreign_key: :issue_id)
    has_one(:last_event, Event, foreign_key: :issue_id)

    has_many(:occurrences, Event, foreign_key: :issue_id)
  end

  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [:state, :muted_until])
    |> validate_required([:state])
  end

  def muted?(%__MODULE__{muted_until: nil}), do: false

  def muted?(%__MODULE__{muted_until: muted_until}) do
    DateTime.compare(muted_until, DateTime.utc_now()) == :gt
  end

  def first_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, asc: e.datetime)
  end

  def last_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, desc: e.datetime)
  end
end
