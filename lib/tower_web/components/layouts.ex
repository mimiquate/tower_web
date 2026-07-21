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

  attr :socket, Phoenix.LiveView.Socket, required: true

  def sidebar(assigns) do
    app_name = extract_app_name(assigns.socket)
    assigns = assign(assigns, :app_name, app_name)

    ~H"""
    <div class="fixed top-0 left-0 z-40 w-[233px] h-screen px-3 py-6">
      <div class="bg-tower-bg">
        <div class="flex items-center justify-center gap-3 pb-6">
          <svg class="w-12 h-12" viewBox="0 0 1080 1064" fill="none" xmlns="http://www.w3.org/2000/svg">
            <path d="M616 760.005H768V912.006H312V760.005H464V608.004H616V760.005ZM312 304.001H464V152H616V304.001H768V152H920V456.002H160V152H312V304.001Z" fill="white"/>
          </svg>
          <div class="w-[149px] h-12">
            <p class="font-light font-roboto-slab text-white text-lg">{@app_name}</p>
            <p class="font-light font-roboto-slab text-white text-xs">Tower Monitoring</p>
          </div>
        </div>

        <nav class="pt-6 pb-4 border-t border-b border-tower-line-color">
          <ul>
            <.sidebar_item href="." active={true}>
              <.occurrences_icon />
              <span class="ml-3 text-sm">Occurrences</span>
            </.sidebar_item>
          </ul>
        </nav>
      </div>
    </div>
    """
  end

  attr :href, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  def sidebar_item(assigns) do
    ~H"""
    <li>
      <a
        href={unless @active, do: @href}
        onclick={if @active, do: "return false"}
        class={[
          "flex items-center w-[209px] h-[36px] py-2 px-3 text-white font-roboto-slab font-light text-sm",
          @active && "bg-tower-active"
        ]}
      >
        {render_slot(@inner_block)}
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

  defp extract_app_name(socket) do
    socket.endpoint
    |> Module.split()
    |> List.first()
    |> String.replace(~r/Web$/, "")
    |> String.replace(~r/([a-z])([A-Z])/, "\\1 \\2")
  end
end
