defmodule TowerWeb.Live.Filters do
  @moduledoc false

  alias TowerWeb.DatetimePresets

  @datetime_range_options [
    {"Last hour", "last_hour"},
    {"Last 24 hours", "last_24h"},
    {"Last 7 days", "last_7d"},
    {"Last 14 days", "last_14d"},
    {"Last 30 days", "last_30d"},
    {"All time", "all_time"}
  ]

  def datetime_range_options, do: @datetime_range_options

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

  def any_active?(filters) do
    Enum.any?(filters, fn {_key, value} -> value not in [nil, "", []] end)
  end
end
