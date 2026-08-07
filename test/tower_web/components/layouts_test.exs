defmodule TowerWeb.LayoutsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias TowerWeb.Layouts

  defp socket_for(view) do
    %Phoenix.LiveView.Socket{
      view: view,
      endpoint: TowerWeb.TestEndpoint
    }
  end

  defp li_containing(html, text) do
    ~r/<li>.*?<\/li>/s
    |> Regex.scan(html)
    |> List.flatten()
    |> Enum.find(&(&1 =~ text))
  end

  describe "sidebar/1" do
    test "renders absolute hrefs for inactive sections" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Occurrences.Index),
          base_path: "/tower"
        })

      assert html =~ ~s(href="/tower/dashboard")
    end

    test "marks Occurrences active when the current view is Occurrences.Index" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Occurrences.Index),
          base_path: "/tower"
        })

      occurrences_li = li_containing(html, "Occurrences")
      dashboard_li = li_containing(html, "Dashboard")

      assert occurrences_li =~ "bg-tower-active"
      refute dashboard_li =~ "bg-tower-active"
    end

    test "marks Occurrences active when the current view is Occurrences.Show" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Occurrences.Show),
          base_path: "/tower"
        })

      occurrences_li = li_containing(html, "Occurrences")

      assert occurrences_li =~ "bg-tower-active"
    end

    test "marks Dashboard active when the current view is Dashboard.Index" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Dashboard.Index),
          base_path: "/tower"
        })

      dashboard_li = li_containing(html, "Dashboard")
      occurrences_li = li_containing(html, "Occurrences")

      assert dashboard_li =~ "bg-tower-active"
      refute occurrences_li =~ "bg-tower-active"
    end
  end
end
