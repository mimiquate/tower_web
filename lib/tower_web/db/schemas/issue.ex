defmodule TowerWeb.DB.Issue do
  use Ecto.Schema

  import Ecto.Changeset

  alias TowerWeb.DB.Event

  @primary_key {:id, :integer, autogenerate: false}
  schema "tower_web_issues" do
    field(:count_events, :integer)
    field(:first_seen, :utc_datetime_usec)
    field(:last_seen, :utc_datetime_usec)

    field(:level, Ecto.Enum,
      values: [:debug, :info, :emergency, :alert, :critical, :error, :warning, :notice]
    )

    field(:normalized_reason, :string)
    field(:stacktrace, TowerWeb.DB.Types.Term)

    has_many(:occurrences, Event, foreign_key: :similarity_id)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(issue, attrs) do
    issue
    |> cast(attrs, [
      :id,
      :count_events,
      :first_seen,
      :last_seen,
      :level,
      :normalized_reason,
      :stacktrace
    ])
    |> validate_required([
      :id,
      :count_events,
      :first_seen,
      :last_seen,
      :level,
      :normalized_reason
    ])
  end
end
