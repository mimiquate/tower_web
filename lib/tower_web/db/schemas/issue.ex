defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  alias TowerWeb.DB.Event

  schema "tower_web_issues" do
    has_many(:occurrences, Event, foreign_key: :issue_id)
  end
end
