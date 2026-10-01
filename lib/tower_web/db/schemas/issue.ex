defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  import Ecto.Changeset

  alias TowerWeb.DB.Event

  @primary_key {:id, :integer, autogenerate: false}
  schema "tower_web_issues" do
    field(:state, Ecto.Enum, values: [:unresolved, :resolved], default: :unresolved)

    has_many(:occurrences, Event, foreign_key: :issue_id)
  end

  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [:id, :state])
    |> validate_required([:id])
  end
end
