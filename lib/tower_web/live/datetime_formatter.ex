defmodule TowerWeb.Live.DatetimeFormatter do
  @moduledoc false

  def format_date(datetime) do
    Calendar.strftime(datetime, "%d/%m/%Y")
  end

  def format_time(datetime) do
    milliseconds =
      datetime.microsecond
      |> elem(0)
      |> div(1000)
      |> Integer.to_string()
      |> String.pad_leading(3, "0")

    Calendar.strftime(datetime, "%I:%M:%S.#{milliseconds} %p %Z")
  end
end
