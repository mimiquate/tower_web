defmodule TowerWeb.Layouts do
  @moduledoc false

  use TowerWeb.Web, :html

  phoenix_js_paths =
    for app <- ~w[phoenix phoenix_html phoenix_live_view]a do
      path = Application.app_dir(app, ["priv", "static", "#{app}.js"])
      Module.put_attribute(__MODULE__, :external_resource, path)
      path
    end

  @js Enum.map_join(phoenix_js_paths, "\n", fn path ->
    path |> File.read!() |> String.replace("//# sourceMappingURL=", "// ")
  end)

  @default_socket_config %{path: "/live", transport: :websocket}

  embed_templates "layouts/*"

  def get_content(:js), do: @js

  def get_socket_config(key) do
    default = Map.get(@default_socket_config, key)
    config = Application.get_env(:tower_web, :live_view_socket, [])
    Keyword.get(config, key, default)
  end
end
