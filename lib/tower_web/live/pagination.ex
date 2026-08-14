defmodule TowerWeb.Live.Pagination do
  @moduledoc false

  def parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, _} when num > 0 -> num
      _ -> 1
    end
  end

  def total_pages(total_count, per_page) do
    max(ceil(total_count / per_page), 1)
  end

  def page_items(_current_page, total_pages) when total_pages <= 7 do
    Enum.to_list(1..total_pages)
  end

  def page_items(current_page, total_pages) do
    cond do
      current_page <= 4 ->
        Enum.to_list(1..5) ++ [:ellipsis, total_pages]

      current_page >= total_pages - 3 ->
        [1, :ellipsis] ++ Enum.to_list((total_pages - 4)..total_pages)

      true ->
        [1, :ellipsis] ++
          Enum.to_list((current_page - 1)..(current_page + 1)) ++ [:ellipsis, total_pages]
    end
  end
end
