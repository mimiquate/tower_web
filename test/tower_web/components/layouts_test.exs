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

  defp extract_href(html, prefix) do
    [_full, href] = Regex.run(~r/href="(#{Regex.escape(prefix)}[^"]*)"/, html)
    String.replace(href, "&amp;", "&")
  end

  defp li_containing(html, text) do
    ~r/<li>.*?<\/li>/s
    |> Regex.scan(html)
    |> List.flatten()
    |> Enum.find(&(&1 =~ text))
  end

  describe "sidebar/1" do
    test "renders absolute hrefs for inactive sections with no filters" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Occurrences.Index),
          base_path: "/tower",
          current_filters: []
        })

      assert html =~ ~s(href="/tower/dashboard")
      assert html =~ ~s(href="/tower/issues")
    end

    test "projects current_filters onto each destination's allowed keys" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Issues.Index),
          base_path: "/tower",
          current_filters: [
            search: "timeout",
            level: "error",
            datetime_range: "last_7d",
            issue_ids: ["42"]
          ]
        })

      dashboard_href = extract_href(html, "/tower/dashboard")
      %URI{path: path, query: query} = URI.parse(dashboard_href)

      assert path == "/tower/dashboard"

      assert URI.decode_query(query) == %{
               "search" => "timeout",
               "level" => "error",
               "datetime_range" => "last_7d"
             }

      occurrences_li = li_containing(html, "Occurrences")
      assert occurrences_li =~ "issue_ids=42"
    end

    test "marks Occurrences active when the current view is Occurrences.Index" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Occurrences.Index),
          base_path: "/tower",
          current_filters: []
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
          base_path: "/tower",
          current_filters: []
        })

      occurrences_li = li_containing(html, "Occurrences")

      assert occurrences_li =~ "bg-tower-active"
    end

    test "marks Dashboard active when the current view is Dashboard.Index" do
      html =
        render_component(&Layouts.sidebar/1, %{
          socket: socket_for(TowerWeb.Live.Dashboard.Index),
          base_path: "/tower",
          current_filters: []
        })

      dashboard_li = li_containing(html, "Dashboard")
      occurrences_li = li_containing(html, "Occurrences")

      assert dashboard_li =~ "bg-tower-active"
      refute occurrences_li =~ "bg-tower-active"
    end
  end
end
