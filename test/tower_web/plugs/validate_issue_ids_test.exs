defmodule TowerWeb.Plugs.ValidateIssueIdsTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn

  alias TowerWeb.Plugs.ValidateIssueIds

  defp call(params) do
    :get
    |> conn("/issues", params)
    |> fetch_query_params()
    |> ValidateIssueIds.call(ValidateIssueIds.init([]))
  end

  test "passes the request through when issue_ids is absent" do
    conn = call(%{})

    refute conn.halted
    assert conn.status == nil
  end

  test "passes the request through when issue_ids is empty" do
    conn = call(%{"issue_ids" => ""})

    refute conn.halted
  end

  test "passes the request through when issue_ids is fully valid UUIDs" do
    conn =
      call(%{
        "issue_ids" => "018e5c33-1b1b-7c3a-8f1a-111111111111,018e5c33-1b1b-7c3a-8f1a-222222222222"
      })

    refute conn.halted
  end

  test "halts with 400 when issue_ids contains a non-UUID value" do
    conn = call(%{"issue_ids" => "018e5c33-1b1b-7c3a-8f1a-111111111111,abc"})

    assert conn.halted
    assert conn.status == 400

    assert conn.resp_body ==
             "Invalid issue_ids parameter. Expected UUID format."
  end
end
