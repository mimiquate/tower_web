defmodule TowerWeb.Router do
  @moduledoc false

  defmacro tower_dashboard(path, opts \\ []) do
    caller_module = __CALLER__.module
    app_name = extract_app_name(caller_module)

    quote bind_quoted: [path: path, opts: opts, app_name: app_name] do
      Application.put_env(:tower_web, :app_name, app_name)

      scoped_path = Phoenix.Router.scoped_path(__MODULE__, path)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        session_name = Keyword.get(opts, :as, :tower_dashboard)
        on_mount = Keyword.get(opts, :on_mount, [])

        live_session session_name,
          on_mount: on_mount,
          root_layout: {TowerWeb.Layouts, :root},
          session: %{"base_path" => scoped_path} do
          live "/", TowerWeb.Live.Occurrences.Index, :index
          live "/:id", TowerWeb.Live.Occurrences.Show, :show
        end
      end
    end
  end

  defp extract_app_name(module) do
    module
    |> Module.split()
    |> List.first()
    |> String.replace(~r/Web$/, "")
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
  end
end
