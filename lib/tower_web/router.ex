defmodule TowerWeb.Router do
  @moduledoc false

  defmacro tower_dashboard(path, opts \\ []) do

    quote bind_quoted: [path: path, opts: opts] do

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        session_name = Keyword.get(opts, :as, :tower_dashboard)
        on_mount = Keyword.get(opts, :on_mount, [])

        live_session session_name,
          on_mount: on_mount,
          root_layout: {TowerWeb.Layouts, :root} do
          live "/", TowerWeb.Live.Occurrences.Index, :index
        end
      end
    end
  end
end
