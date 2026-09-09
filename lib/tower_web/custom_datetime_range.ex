defmodule TowerWeb.CustomDatetimeRange do
  @moduledoc false

  @max_days 30

  def max_days, do: @max_days

  def default_range do
    to = DateTime.utc_now()
    from = DateTime.add(to, -@max_days, :day)

    {format_input(from), format_input(to)}
  end

  def range_for(from, to) when from in [nil, ""] and to in [nil, ""], do: []

  def range_for(from, to) do
    with {:ok, from_dt} <- bound(from, ~T[00:00:00], fn -> ~U[1970-01-01 00:00:00Z] end),
         {:ok, to_dt} <- bound(to, ~T[23:59:59], fn -> DateTime.utc_now() end),
         true <- DateTime.compare(from_dt, to_dt) != :gt do
      {clamp_from(from_dt, to_dt), to_dt}
    else
      _ -> []
    end
  end

  def format_bound(value) do
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

  defp bound(value, _time, default_fun) when value in [nil, ""], do: {:ok, default_fun.()}

  defp bound(value, time, _default_fun) do
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

  defp clamp_from(from_dt, to_dt) do
    min_from_dt = DateTime.add(to_dt, -@max_days, :day)

    if DateTime.compare(from_dt, min_from_dt) == :lt, do: min_from_dt, else: from_dt
  end

  defp format_input(datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
end
