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

  def sidebar(assigns) do
    assigns = assign(assigns, :app_name, get_app_name())

    ~H"""
    <aside class="fixed top-0 left-0 z-40 w-64 h-screen">
      <div class="h-full px-3 py-4 overflow-y-auto bg-tower-bg flex flex-col gap-3">
        <div class="px-2 pb-4">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-gray-700 flex items-center justify-center">
              <span class="text-xl text-white">T</span>
            </div>
            <div>
              <p class="font-light font-tower text-white text-lg">{@app_name}</p>
              <p class="font-light font-tower text-white text-sm">Tower Monitoring</p>
            </div>
          </div>
        </div>

        <nav class="py-4 border-t border-b border-tower-line-color">
          <ul class="space-y-2">
            <.sidebar_item href="." active={true}>
              <.occurrences_icon />
              <span class="ml-3 text-sm">Occurrences</span>
            </.sidebar_item>
          </ul>
        </nav>
      </div>
    </aside>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  attr :disabled, :boolean, default: false
  slot :inner_block, required: true

  def sidebar_item(assigns) do
    ~H"""
    <li>
      <a
        href={unless @disabled || @active, do: @href, else: "#"}
        class={[
          "flex items-center p-2 transition-colors",
          @active && "bg-tower-active text-white cursor-default",
          !@active && !@disabled && "text-gray-400 hover:bg-gray-700 hover:text-white",
          @disabled && "text-gray-600 cursor-not-allowed"
        ]}
      >
        {render_slot(@inner_block)}
        <span :if={@disabled} class="ml-auto text-xs text-gray-600">Soon</span>
      </a>
    </li>
    """
  end

  defp occurrences_icon(assigns) do
    ~H"""
    <svg class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8" />
      <path d="M3 3v5h5" />
      <path d="M12 7v5l4 2" />
    </svg>
    """
  end

  defp get_app_name do
    Application.get_env(:tower_web, :app_name, "Project Name")
  end
end
