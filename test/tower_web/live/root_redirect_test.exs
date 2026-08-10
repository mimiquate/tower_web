defmodule TowerWeb.Live.RootRedirectTest do
  use ExUnit.Case, async: true

  alias TowerWeb.Live.RootRedirect

  describe "mount/3" do
    test "redirects to <base_path>/dashboard" do
      socket = %Phoenix.LiveView.Socket{}

      {:ok, socket} = RootRedirect.mount(%{}, %{"base_path" => "/tower"}, socket)

      assert socket.redirected == {:redirect, %{to: "/tower/dashboard", status: 302}}
    end
  end
end
