defmodule TowerWeb.Live.Selection do
  @moduledoc false

  def toggle(selected_ids, id) do
    if MapSet.member?(selected_ids, id) do
      MapSet.delete(selected_ids, id)
    else
      MapSet.put(selected_ids, id)
    end
  end

  def toggle_all(selected_ids, visible_ids) do
    if MapSet.subset?(visible_ids, selected_ids) do
      MapSet.difference(selected_ids, visible_ids)
    else
      MapSet.union(selected_ids, visible_ids)
    end
  end

  def all_selected?(items, selected_ids, id_fun \\ & &1.id) do
    Enum.all?(items, &MapSet.member?(selected_ids, id_fun.(&1)))
  end

  def item_label(1), do: "item"
  def item_label(_count), do: "items"
end
