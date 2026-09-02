defmodule TowerWeb.Live.Level do
  @moduledoc false

  @levels ~w(emergency alert critical error warning notice info)

  def levels, do: @levels

  def validate_level(level) when level in @levels, do: level
  def validate_level(_level), do: nil

  def level_class(level) when level in [:error, :alert, :emergency, :critical] do
    "text-red-500"
  end

  def level_class(level) when level in [:warning] do
    "text-yellow-500"
  end

  def level_class(_level) do
    "text-gray-400"
  end
end
