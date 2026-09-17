defmodule TowerWeb.Live.Filters do
  @moduledoc false

  alias TowerWeb.DatetimePresets
  alias TowerWeb.Live.Level

  @allowed_filter_keys [:search, :level, :datetime_range, :issue_ids]

  def allowed_filter_keys, do: @allowed_filter_keys

  @datetime_range_options [
    {"Last hour", "last_hour"},
    {"Last 24 hours", "last_24h"},
    {"Last 7 days", "last_7d"},
    {"Last 14 days", "last_14d"},
    {"Last 30 days", "last_30d"},
    {"All time", "all_time"}
  ]

  def datetime_range_options, do: @datetime_range_options

  def default_assigns do
    %{
      datetime_range_options: @datetime_range_options,
      datetime_range_menu_open: false,
      levels: Level.levels()
    }
  end

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

  def for_path(filters, allowed_keys) do
    Keyword.take(filters, allowed_keys)
  end

  def parse_params(params) do
    datetime_range_param = params["datetime_range"] || "last_7d"

    %{
      search: Map.get(params, "search", ""),
      level: params |> Map.get("level", "") |> Level.validate_level(),
      datetime_range_param: datetime_range_param,
      datetime_range: datetime_range(datetime_range_param),
      issue_ids: params |> Map.get("issue_ids", "") |> parse_issue_ids()
    }
  end

  def current_filters(assigns, overrides \\ []) do
    [
      search: assigns.search_query,
      level: assigns.selected_level,
      issue_ids: assigns.issue_ids_filtered,
      datetime_range: assigns.datetime_range_param
    ]
    |> Keyword.merge(overrides)
  end

  def clear_filter(assigns, "issue_id", id_to_remove) do
    new_issue_ids = Enum.reject(assigns.issue_ids_filtered, &(&1 == id_to_remove))
    current_filters(assigns, issue_ids: new_issue_ids)
  end

  def clear_filter(assigns, type) do
    datetime_range_filter = [datetime_range: assigns.datetime_range_param]

    case type do
      "all" -> [search: "", level: nil, datetime_range: "", issue_ids: []]
      "search" -> current_filters(assigns, search: "") ++ datetime_range_filter
      "level" -> current_filters(assigns, level: nil) ++ datetime_range_filter
    end
  end
end
