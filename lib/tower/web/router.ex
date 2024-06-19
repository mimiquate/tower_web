defmodule Tower.Web.Router do
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> render("home.html")
  end

  defp render(%{status: status} = conn, template, assigns \\ []) do
    conn
    |> send_resp(
      status || 200,
      # TODO: Refactor to make it work for self-contained releases
      Path.dirname(__ENV__.file)
      |> Path.join("templates")
      |> Path.join(template)
      |> String.replace_suffix(".html", ".html.eex")
      |> EEx.eval_file(assigns)
    )
  end
end
