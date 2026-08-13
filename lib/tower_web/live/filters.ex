defmodule TowerWeb.Live.Filters do
  @moduledoc false

  alias TowerWeb.DatetimePresets

  @levels ~w(emergency alert critical error warning notice info)
  @datetime_range_options [
    {"All time", ""},
    {"Last hour", "last_hour"},
    {"Last 24 hours", "last_24h"},
    {"Last 7 days", "last_7d"},
    {"Last 14 days", "last_14d"},
    {"Last 30 days", "last_30d"}
  ]

  def levels, do: @levels
  def datetime_range_options, do: @datetime_range_options

  def validate_level(level) when level in @levels, do: level
  def validate_level(_level), do: nil

  def datetime_range(datetime_range_param) do
    case DatetimePresets.cast(datetime_range_param) do
      nil -> []
      preset -> DatetimePresets.range_for(preset)
    end
  end

  def datetime_range_label(value) do
    Enum.find_value(@datetime_range_options, value, fn {label, option_value} ->
      if option_value == value, do: label
    end)
  end

  def parse_issue_ids(""), do: []

  def parse_issue_ids(issue_ids_string) do
    issue_ids_string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.filter(&(&1 != ""))
  end

  def compact_filters(filters) do
    Enum.reject(filters, fn {_key, value} -> value in ["", []] end)
  end
end
