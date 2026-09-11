defmodule TowerWeb.Layouts do
  @moduledoc false

  use TowerWeb.Web, :html

  alias TowerWeb.Live.Filters
  alias TowerWeb.Live.Paths

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

  embed_templates("layouts/*")

  def get_content(:js), do: @js

  def get_socket_config(key) do
    default = Map.get(@default_socket_config, key)
    config = Application.get_env(:tower_web, :live_view_socket, [])
    Keyword.get(config, key, default)
  end

  attr(:socket, Phoenix.LiveView.Socket, required: true)
  attr(:base_path, :string, required: true)
  attr(:current_filters, :list, default: [])

  def sidebar(assigns) do
    app_name = extract_app_name(assigns.socket)

    assigns =
      assigns
      |> assign(:app_name, app_name)
      |> assign(:items, sidebar_items(assigns.base_path, assigns.current_filters))
      |> assign(:current_view, assigns.socket.view)

    ~H"""
    <div class="fixed top-0 left-0 z-40 w-sidebar h-screen px-3 py-6 flex flex-col border-r border-tower-line-color">
      <div class="bg-tower-bg flex flex-col flex-1 min-h-0">
        <div class="flex items-center justify-start gap-3 pb-6">
          <.tower_logo />
          <div class="w-[180px] h-12">
            <p class="font-light font-roboto-slab text-white text-lg truncate" title={@app_name}>{@app_name}</p>
            <p class="font-light font-roboto-slab text-white text-xs">Tower Monitoring</p>
          </div>
        </div>

        <nav class="pt-6 pb-4 border-t border-b border-tower-line-color">
          <ul class="flex flex-col gap-3">
            <.sidebar_item
              :for={item <- @items}
              href={item.href}
              active={@current_view in item.views}
              disabled={@current_view == hd(item.views)}
            >
              {item.icon.(%{})}
              <span class="ml-3 text-sm">{item.label}</span>
            </.sidebar_item>
          </ul>
        </nav>

        <div class="flex gap-3 items-center mt-auto">
          <.mimiquate_logo />
          <p class="flex-1 font-roboto-slab text-white text-[8px] tracking-[-0.15px]">
            Product built by Mimiquate © 2025. This project is open source and community-driven.
          </p>
        </div>
      </div>
    </div>
    """
  end

  defp sidebar_items(base_path, current_filters) do
    [
      %{
        href:
          Paths.index_path(
            "#{base_path}/dashboard",
            Filters.for_path(current_filters, TowerWeb.Live.Dashboard.Index.allowed_filter_keys())
          ),
        label: "Dashboard",
        views: [TowerWeb.Live.Dashboard.Index],
        icon: &dashboard_icon/1
      },
      %{
        href:
          Paths.index_path(
            "#{base_path}/issues",
            Filters.for_path(current_filters, TowerWeb.Live.Issues.Index.allowed_filter_keys())
          ),
        label: "Issues",
        views: [TowerWeb.Live.Issues.Index, TowerWeb.Live.Issues.Show],
        icon: &issues_icon/1
      },
      %{
        href:
          Paths.index_path(
            "#{base_path}/occurrences",
            Filters.for_path(
              current_filters,
              TowerWeb.Live.Occurrences.Index.allowed_filter_keys()
            )
          ),
        label: "Occurrences",
        views: [TowerWeb.Live.Occurrences.Index, TowerWeb.Live.Occurrences.Show],
        icon: &occurrences_icon/1
      }
    ]
  end

  attr(:href, :string, required: true)
  attr(:active, :boolean, default: false)
  attr(:disabled, :boolean, default: false)
  slot(:inner_block, required: true)

  def sidebar_item(assigns) do
    ~H"""
    <li>
      <.link
        :if={not @disabled}
        navigate={@href}
        class={[
          "flex items-center w-[240px] h-[36px] py-2 px-3 text-white font-roboto-slab font-light text-sm",
          @active && "bg-tower-active"
        ]}
      >
        {render_slot(@inner_block)}
      </.link>
      <a
        :if={@disabled}
        onclick="return false"
        class="flex items-center w-[240px] h-[36px] py-2 px-3 text-white font-roboto-slab font-light text-sm bg-tower-active"
      >
        {render_slot(@inner_block)}
      </a>
    </li>
    """
  end

  defp tower_logo(assigns) do
    ~H"""
    <svg class="w-12 h-12" viewBox="0 0 1080 1064" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M616 760.005H768V912.006H312V760.005H464V608.004H616V760.005ZM312 304.001H464V152H616V304.001H768V152H920V456.002H160V152H312V304.001Z" fill="white"/>
    </svg>
    """
  end

  defp issues_icon(assigns) do
    ~H"""
    <svg class="w-5 h-5" width="16" height="14" viewBox="0 0 16 14" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M5.30492 13.1656V11.7955H15.5282V13.1656H5.30492ZM5.30492 7.68507V6.31493H15.5282V7.68507H5.30492ZM5.30492 2.20454V0.834409H15.5282V2.20454H5.30492ZM1.51948 14C1.10159 14 0.743905 13.8512 0.446434 13.5536C0.148812 13.2561 0 12.8984 0 12.4805C0 12.0626 0.148812 11.705 0.446434 11.4075C0.743905 11.1099 1.10159 10.961 1.51948 10.961C1.93737 10.961 2.29505 11.1099 2.59252 11.4075C2.89014 11.705 3.03895 12.0626 3.03895 12.4805C3.03895 12.8984 2.89014 13.2561 2.59252 13.5536C2.29505 13.8512 1.93737 14 1.51948 14ZM1.51948 8.51948C1.10159 8.51948 0.743905 8.37066 0.446434 8.07304C0.148812 7.77557 0 7.41789 0 7C0 6.58211 0.148812 6.22443 0.446434 5.92696C0.743905 5.62934 1.10159 5.48053 1.51948 5.48053C1.93737 5.48053 2.29505 5.62934 2.59252 5.92696C2.89014 6.22443 3.03895 6.58211 3.03895 7C3.03895 7.41789 2.89014 7.77557 2.59252 8.07304C2.29505 8.37066 1.93737 8.51948 1.51948 8.51948ZM1.51948 3.03895C1.10159 3.03895 0.743905 2.89014 0.446434 2.59252C0.148812 2.29505 0 1.93737 0 1.51948C0 1.10159 0.148812 0.743905 0.446434 0.446434C0.743905 0.148811 1.10159 0 1.51948 0C1.93737 0 2.29505 0.148811 2.59252 0.446434C2.89014 0.743905 3.03895 1.10159 3.03895 1.51948C3.03895 1.93737 2.89014 2.29505 2.59252 2.59252C2.29505 2.89014 1.93737 3.03895 1.51948 3.03895Z" fill="white"/>
    </svg>
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

  defp dashboard_icon(assigns) do
    ~H"""
    <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
      <mask id="mask0_1533_424" style="mask-type:alpha" maskUnits="userSpaceOnUse" x="0" y="0" width="20" height="20">
        <rect width="20" height="20" fill="#D9D9D9"/>
      </mask>
      <g mask="url(#mask0_1533_424)">
        <path d="M11 7V3H17V7H11ZM3 11V3H9V11H3ZM11 17V9H17V17H11ZM3 17V13H9V17H3ZM4.5 9.5H7.5V4.5H4.5V9.5ZM12.5 15.5H15.5V10.5H12.5V15.5ZM12.5 5.52083H15.5V4.5H12.5V5.52083ZM4.5 15.5H7.5V14.5H4.5V15.5Z" fill="white"/>
      </g>
    </svg>
    """
  end

  defp mimiquate_logo(assigns) do
    ~H"""
    <svg class="w-12 h-12" viewBox="0 0 48 48" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path d="M36.0316 24.3784C37.3993 20.4386 39.5256 17.2455 39.8772 16.6911C40.2096 16.1667 39.8216 15.5727 39.2576 15.4357C38.6768 15.2947 37.8496 15.5513 37.4256 15.7869C36.2527 16.4389 35.4205 17.2493 33.9756 18.8623C33.5519 19.3354 32.3213 20.9029 31.1488 22.4395C30.1921 23.6903 29.2728 24.9201 28.8585 25.5174C29.6552 23.9988 31.4422 21.18 32.95 18.7386C33.5432 17.781 34.0946 16.8807 34.5272 16.1402C34.7798 15.7261 35.0981 15.1824 35.2147 14.9831C35.3701 14.7181 35.4085 14.5001 35.4191 14.1912C35.4421 13.526 34.8522 13.0923 34.256 13.0455C33.4979 12.9861 32.8362 13.2426 32.2168 13.6628C31.6829 14.0252 31.1977 14.4544 30.7429 14.9151C29.2519 16.3334 24.0171 21.9917 23.8724 22.3225C24.5868 20.6891 25.3251 19.0918 26.0883 17.5293C26.5225 16.6413 26.9661 15.7762 27.4163 14.9254C27.4211 14.9184 27.4256 14.9118 27.4306 14.9047L28.4033 13.0578C28.5449 12.7724 28.6548 12.4627 28.6468 12.1432C28.6286 11.4327 27.9723 11.01 27.3339 11.0003C26.5223 10.9879 25.7438 11.3912 25.1109 11.8808C25.1069 11.884 25.1031 11.8877 25.099 11.8907C24.6635 12.2031 24.2132 12.5251 23.7359 12.8656C16.4521 18.06 11.7631 19.4472 8.53964 18.6257C8.3155 18.5685 8.15932 18.6247 8.04588 18.7763C7.79186 19.1156 8.65179 19.8035 9.1727 20.0328C10.0386 20.4141 10.9829 20.7365 10.9829 20.7365C9.76624 21.774 9.1968 21.7617 9.52619 22.0218C9.76929 22.2138 11.4569 22.2852 12.4148 22.0749C14.9654 21.5153 16.8143 20.3339 18.8041 19.0499C19.8943 18.3462 24.1242 14.8646 24.1242 14.8646C23.4658 16.011 22.8186 17.1247 22.1812 18.2066C20.2818 21.4314 18.4705 24.7369 17.0879 28.2322C16.9896 28.4472 16.986 28.7093 17.0773 29.0166C17.2778 29.6924 17.6708 30.2997 18.1455 30.8066C19.509 32.2626 20.2193 31.8928 20.8063 30.2351C21.1851 29.1423 21.8039 27.4312 22.0446 26.792C22.6332 26.0908 23.2527 25.3525 23.9035 24.5789C25.9085 22.1951 28.0515 19.8466 30.3207 17.7016C29.8023 18.4751 29.281 19.2524 28.7554 20.0333C28.5002 20.4129 25.686 25.2578 25.1278 27.5119C25.0862 27.6982 25.1624 27.9626 25.3585 28.3055C25.5541 28.6484 25.7875 28.9842 26.06 29.3136C26.3326 29.6421 26.612 29.9101 26.8986 30.1172C26.9015 30.1192 26.9044 30.1213 26.9071 30.1233C27.2007 30.3334 27.6082 30.2256 27.7892 29.9093C28.7798 28.1796 29.8555 26.4867 31.0171 24.8313C31.462 24.197 34.7132 19.9549 34.9808 19.6299C35.0005 19.6059 35.0198 19.5817 35.0396 19.5575C34.4513 20.5433 31.8545 26.6823 31.6201 30.5828C31.5261 32.1462 31.7708 33.9954 32.8981 35.1569C33.6635 35.9457 34.7529 36.3311 35.7069 35.6429C35.9786 35.4469 36.2903 35.0701 36.0469 34.7385C34.7976 33.0364 34.7247 30.6714 34.9833 28.6424C35.1694 27.1825 36.0314 24.3784 36.0314 24.3784M35.0463 19.5496C35.045 19.5519 35.0433 19.5551 35.042 19.5574L35.0409 19.5562C35.0426 19.5541 35.0446 19.5518 35.0463 19.5495" fill="white"/>
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
