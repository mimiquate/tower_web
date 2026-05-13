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
    ~H"""
    <aside class="fixed top-0 left-0 z-40 w-64 h-screen">
      <div class="h-full px-3 py-4 overflow-y-auto bg-tower-bg flex flex-col">
        <div class="mb-8 px-2">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-gray-700 flex items-center justify-center">
              <span class="text-xl text-white">T</span>
            </div>
            <div>
              <p class="font-thin font-tower-arvo text-white text-lg">ProjectName</p>
              <p class="font-thin font-tower-arvo text-gray-400 text-sm">Tower Monitoring</p>
            </div>
          </div>
        </div>

        <nav class="py-2">
          <ul class="space-y-2">
            <.sidebar_item href="." active={true}>
              <.occurrences_icon />
              <span class="ml-3">Occurrences</span>
            </.sidebar_item>
          </ul>
        </nav>

        <nav class="flex-1 py-2">
          <ul class="space-y-2">
            <.sidebar_item href="#" active={false} disabled={true}>
              <.settings_icon />
              <span class="ml-3">Settings</span>
            </.sidebar_item>
          </ul>
        </nav>

        <div class="mt-auto px-2 py-4 border-t border-gray-700">
          <p class="text-xs text-gray-500">TowerWeb v0.1.0</p>
        </div>
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
        href={unless @disabled, do: @href, else: "#"}
        class={[
          "flex items-center p-2 transition-colors",
          @active && "bg-tower-active text-white",
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

  defp settings_icon(assigns) do
    ~H"""
    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
      />
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
      />
    </svg>
    """
  end
end
