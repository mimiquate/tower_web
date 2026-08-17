defmodule TowerWeb.Live.Paths do
  @moduledoc false

  def filters_to_params(base, filters) do
    Enum.reduce(filters, base, fn
      {_key, nil}, acc -> acc
      {_key, ""}, acc -> acc
      {_key, []}, acc -> acc
      {key, value}, acc when is_list(value) -> Map.put(acc, key, Enum.join(value, ","))
      {key, value}, acc -> Map.put(acc, key, value)
    end)
  end

  def page_path(page, filters) do
    params = filters_to_params(%{page: page}, filters)
    "?#{URI.encode_query(params)}"
  end
end
