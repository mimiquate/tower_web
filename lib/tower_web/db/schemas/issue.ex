defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  import Ecto.Query

  alias TowerWeb.DB.Event

  schema "tower_web_issues" do
    field(:count_events, :integer, virtual: true)

    has_one(:first_event, Event, foreign_key: :issue_id)
    has_one(:last_event, Event, foreign_key: :issue_id)
    has_many(:occurrences, Event, foreign_key: :issue_id)
  end

  def first_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, asc: e.datetime)
  end

  def last_event_query do
    Event |> distinct([e], e.issue_id) |> order_by([e], asc: e.issue_id, desc: e.datetime)
  end
end
