defmodule TowerWeb.Live.Occurrences.Paths do
  @moduledoc false

  def filters_to_params(base, filters) do
    Enum.reduce(filters, base, fn
      {_key, nil}, acc -> acc
      {_key, ""}, acc -> acc
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end
end
