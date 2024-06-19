defmodule Tower.Web.Router do
  use Plug.Router

  plug :match
  plug :dispatch

  get "/" do
    send_resp(conn, 200, "Hello from Tower Web")
  end
end
