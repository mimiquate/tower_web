defmodule TowerWeb.Plugs.ValidateIssueIds do
  @moduledoc false

  import Plug.Conn

  alias TowerWeb.Live.Filters

  def init(opts), do: opts

  def call(%Plug.Conn{params: %{"issue_ids" => value}} = conn, _opts) when value != "" do
    if Filters.valid_issue_ids?(value) do
      conn
    else
      conn
      |> send_resp(
        400,
        "Invalid issue_ids parameter. Expected numeric format."
      )
      |> halt()
    end
  end

  def call(conn, _opts), do: conn
end
