defmodule TowerWeb.Live.Dashboard.IndexTest do
  use TowerWeb.DataCase

  import Phoenix.LiveViewTest

  alias TowerWeb.Live.Dashboard.Index, as: Dashboard

  describe "render/1" do
    test "shows total errors and total occurrences" do
      html =
        render_component(&Dashboard.render/1, %{
          total_errors: 3,
          total_occurrences: 7
        })

      assert html =~ "Total Errors"
      assert html =~ "3"
      assert html =~ "Total Occurrences"
      assert html =~ "7"
    end
  end
end
