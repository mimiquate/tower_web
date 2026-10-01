defmodule TowerWeb.Router do
  @moduledoc false

  defmacro tower_dashboard(path, opts \\ []) do
    quote bind_quoted: [path: path, opts: opts] do
      scoped_path = Phoenix.Router.scoped_path(__MODULE__, path)
      session_name = Keyword.get(opts, :as, :tower_dashboard)
      pipeline_name = :"#{session_name}_validate_issue_ids"

      pipeline pipeline_name do
        plug(TowerWeb.Plugs.ValidateIssueIds)
      end

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        pipe_through(pipeline_name)

        on_mount = Keyword.get(opts, :on_mount, [])

        live_session session_name,
          on_mount: on_mount,
          root_layout: {TowerWeb.Layouts, :root},
          session: %{"base_path" => scoped_path} do
          live("/", TowerWeb.Live.RootRedirect, :index)
          live("/dashboard", TowerWeb.Live.Dashboard.Index, :index)
          live("/issues", TowerWeb.Live.Issues.Index, :index)
          live("/issues/:id", TowerWeb.Live.Issues.Show, :show)
          live("/occurrences", TowerWeb.Live.Occurrences.Index, :index)
          live("/occurrences/:id", TowerWeb.Live.Occurrences.Show, :show)
        end
      end
    end
  end
end
