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
  @max_custom_range_days 30

  def levels, do: @levels
  def datetime_range_options, do: @datetime_range_options

  def default_custom_range do
    to = DateTime.utc_now()
    from = DateTime.add(to, -@max_custom_range_days, :day)

    {format_datetime(from), format_datetime(to)}
  end

  def toggle_custom_range(assigns) do
    custom_open = !assigns.datetime_range_custom_open

    if custom_open and assigns.datetime_range_from in [nil, ""] and
         assigns.datetime_range_to in [nil, ""] do
      {from, to} = default_custom_range()
      %{datetime_range_custom_open: true, datetime_range_from: from, datetime_range_to: to}
    else
      %{datetime_range_custom_open: custom_open}
    end
  end

  def datetime_range(datetime_range_param, from \\ nil, to \\ nil)

  def datetime_range("custom", from, to) when from in [nil, ""] and to in [nil, ""] do
    []
  end

  def datetime_range("custom", from, to) do
    with {:ok, from_dt} <- custom_bound(from, ~T[00:00:00], ~U[1970-01-01 00:00:00Z]),
         {:ok, to_dt} <- custom_bound(to, ~T[23:59:59], DateTime.utc_now()),
         :lt_or_eq <- compare(from_dt, to_dt) do
      {clamp_from(from_dt, to_dt), to_dt}
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
    trimmed = String.trim(value)

    with {:error, _} <- date_only(trimmed, time) do
      full_datetime(trimmed)
    end
  end

  defp date_only(value, time) do
    case Date.from_iso8601(value) do
      {:ok, date} -> DateTime.new(date, time, "Etc/UTC")
      error -> error
    end
  end

  defp full_datetime(value) do
    case parse_flexible_naive_datetime(value) do
      {:ok, naive} -> DateTime.from_naive(naive, "Etc/UTC")
      error -> error
    end
  end

  defp parse_flexible_naive_datetime(value) do
    NaiveDateTime.from_iso8601(String.replace(value, " ", "T", global: false))
  end

  defp compare(from_dt, to_dt) do
    if DateTime.compare(from_dt, to_dt) in [:lt, :eq], do: :lt_or_eq, else: :gt
  end

  defp clamp_from(from_dt, to_dt) do
    min_from_dt = DateTime.add(to_dt, -@max_custom_range_days, :day)

    if DateTime.compare(from_dt, min_from_dt) == :lt, do: min_from_dt, else: from_dt
  end

  def datetime_range_label(value, from \\ nil, to \\ nil)

  def datetime_range_label("custom", from, to)
      when from not in [nil, ""] and to not in [nil, ""] do
    "#{format_custom_date(from)} - #{format_custom_date(to)}"
  end

  def datetime_range_label("custom", from, _to) when from not in [nil, ""] do
    "From #{format_custom_date(from)}"
  end

  def datetime_range_label("custom", _from, to) when to not in [nil, ""] do
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
    trimmed = String.trim(value)

    case parse_flexible_naive_datetime(trimmed) do
      {:ok, naive} ->
        Calendar.strftime(naive, "%b %-d, %H:%M")

      _ ->
        case Date.from_iso8601(trimmed) do
          {:ok, date} -> Calendar.strftime(date, "%b %-d")
          _ -> trimmed
        end
    end
  end

  defp format_datetime(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")

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
