defmodule TowerWeb.StacktraceTest do
  use ExUnit.Case, async: false

  alias TowerWeb.Stacktrace

  @host_frame {TowerWeb.Stacktrace, :pick_frame, 1,
               [file: ~c"lib/tower_web/stacktrace.ex", line: 23]}
  @library_frame {Enum, :map, 2, [file: ~c"lib/enum.ex", line: 1658]}
  @other_library_frame {List, :first, 1, [file: ~c"lib/list.ex", line: 40]}

  describe "host_otp_app/0" do
    test "returns the configured otp_app when it's an atom" do
      assert Stacktrace.host_otp_app() == :tower_web
    end

    test "raises when :otp_app isn't configured at all" do
      original = Application.get_env(:tower_web, :otp_app)
      Application.delete_env(:tower_web, :otp_app)
      on_exit(fn -> Application.put_env(:tower_web, :otp_app, original) end)

      assert_raise ArgumentError, fn -> Stacktrace.host_otp_app() end
    end

    test "raises when :otp_app is configured to something other than an atom" do
      original = Application.get_env(:tower_web, :otp_app)
      Application.put_env(:tower_web, :otp_app, "tower_web")
      on_exit(fn -> Application.put_env(:tower_web, :otp_app, original) end)

      assert_raise ArgumentError, ~r/expected :tower_web, :otp_app to be an atom/, fn ->
        Stacktrace.host_otp_app()
      end
    end
  end

  describe "pick_frame/1" do
    test "picks the closest frame belonging to the host app" do
      assert Stacktrace.pick_frame([@library_frame, @host_frame]) == @host_frame
    end

    test "falls back to the first frame when none belong to the host app" do
      assert Stacktrace.pick_frame([@library_frame, @other_library_frame]) == @library_frame
    end

    test "returns nil for an empty stacktrace" do
      assert Stacktrace.pick_frame([]) == nil
    end
  end

  describe "normalize_arity/1" do
    test "returns an integer arity unchanged" do
      assert Stacktrace.normalize_arity(2) == 2
    end

    test "returns the length of a captured argument list" do
      assert Stacktrace.normalize_arity(["a", "b", "c"]) == 3
    end
  end

  describe "pick_and_format_last_stacktrace_frame/1" do
    test "formats the picked frame as Module.function/arity" do
      assert Stacktrace.pick_and_format_last_stacktrace_frame([@host_frame]) ==
               "TowerWeb.Stacktrace.pick_frame/1"
    end

    test "returns nil when no frame is picked" do
      assert Stacktrace.pick_and_format_last_stacktrace_frame(nil) == nil
    end
  end
end
