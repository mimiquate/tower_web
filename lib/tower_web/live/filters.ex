defmodule TowerWeb.Live.Filters do
  @moduledoc false

  alias TowerWeb.DatetimePresets

  @levels ~w(emergency alert critical error warning notice info)
  @datetime_range_options [
    {"Last hour", "last_hour"},
    {"Last 24 hours", "last_24h"},
    {"Last 7 days", "last_7d"},
    {"Last 14 days", "last_14d"},
    {"Last 30 days", "last_30d"},
    {"All time", "all_time"}
  ]

  def levels, do: @levels
  def datetime_range_options, do: @datetime_range_options

  def datetime_range(datetime_range_param, from \\ nil, to \\ nil)

  def datetime_range("custom", from, to) when from in [nil, ""] and to in [nil, ""] do
    []
  end

  def datetime_range("custom", from, to) do
    with {:ok, from_dt} <- custom_bound(from, ~T[00:00:00], ~U[1970-01-01 00:00:00Z]),
         {:ok, to_dt} <- custom_bound(to, ~T[23:59:59], DateTime.utc_now()),
         :lt_or_eq <- compare(from_dt, to_dt) do
      {from_dt, to_dt}
    else
      _ -> []
    end
  end

  def datetime_range(datetime_range_param, _from, _to) do
    case DatetimePresets.cast(datetime_range_param) do
      nil -> []
      preset -> DatetimePresets.range_for(preset)
    end
  end

  defp custom_bound(value, _time, default) when value in [nil, ""], do: {:ok, default}

  defp custom_bound(value, time, _default) do
    with {:ok, date} <- Date.from_iso8601(value) do
      DateTime.new(date, time, "Etc/UTC")
    end
  end

  defp compare(from_dt, to_dt) do
    if DateTime.compare(from_dt, to_dt) in [:lt, :eq], do: :lt_or_eq, else: :gt
  end

  def datetime_range_label(value, from \\ nil, to \\ nil)

  def datetime_range_label("custom", from, to)
      when from not in [nil, ""] and to not in [nil, ""] do
    "#{format_custom_date(from)} - #{format_custom_date(to)}"
  end

  def datetime_range_label("custom", from, to) when from not in [nil, ""] do
    "From #{format_custom_date(from)}"
  end

  def datetime_range_label("custom", from, to) when to not in [nil, ""] do
    "Until #{format_custom_date(to)}"
  end

  def datetime_range_label("custom", _from, _to) do
    "Custom"
  end

  def datetime_range_label(value, _from, _to) do
    Enum.find_value(@datetime_range_options, value, fn {label, option_value} ->
      if option_value == value, do: label
    end)
  end

  defp format_custom_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Calendar.strftime(date, "%b %-d")
      _ -> value
    end
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
end
