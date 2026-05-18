defmodule TowerWeb.Router do
  @moduledoc false

  defmacro tower_dashboard(path, opts \\ []) do
    caller_module = __CALLER__.module
    app_name = extract_app_name(caller_module)

    quote bind_quoted: [path: path, opts: opts, app_name: app_name] do
      Application.put_env(:tower_web, :app_name, app_name)

      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4, live_session: 3]

        session_name = Keyword.get(opts, :as, :tower_dashboard)
        on_mount = Keyword.get(opts, :on_mount, [])

        live_session session_name,
          on_mount: on_mount,
          root_layout: {TowerWeb.Layouts, :root} do
          live "/", TowerWeb.Live.Home, :index, as: session_name
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
