defmodule TowerWeb.DB.Repo do
  @moduledoc false

  def repo do
    Application.fetch_env!(:tower_web, :repo)
  end
end
