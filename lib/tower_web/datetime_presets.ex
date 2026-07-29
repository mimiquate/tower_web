defmodule TowerWeb.DatetimePresets do
  @presets ~w(last_hour last_24h last_7d last_14d last_30d)a

  def presets, do: @presets

  def cast(value) when is_binary(value) do
    Enum.find(@presets, &(Atom.to_string(&1) == value))
  end

  def cast(value) when value in @presets, do: value
  def cast(_), do: nil

  def range_for(:last_hour), do: range_from_now(-1, :hour)
  def range_for(:last_24h), do: range_from_now(-1, :day)
  def range_for(:last_7d), do: range_from_now(-7, :day)
  def range_for(:last_14d), do: range_from_now(-14, :day)
  def range_for(:last_30d), do: range_from_now(-30, :day)

  defp range_from_now(amount, unit) do
    now = DateTime.utc_now()
    {DateTime.add(now, amount, unit), now}
  end
end
