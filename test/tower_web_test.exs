defmodule TowerWebTest do
  use ExUnit.Case
  doctest TowerWeb

  test "greets the world" do
    assert TowerWeb.hello() == :world
  end
end
