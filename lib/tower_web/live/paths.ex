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

  def index_path(base_path, filters, extra_params \\ %{}) do
    params = filters_to_params(extra_params, filters)
    "#{base_path}?#{URI.encode_query(params)}"
  end

  def show_path(base_path, id, filters, extra_params \\ %{}) do
    params = filters_to_params(extra_params, filters)
    "#{base_path}/#{id}?#{URI.encode_query(params)}"
  end
end
