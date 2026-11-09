defmodule TowerWeb.DB.SimilarityIdTest do
  use ExUnit.Case, async: true

  alias TowerWeb.DB.SimilarityId

  test "uses the exception module and host app frame for :error events" do
    stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {TowerWeb.DB.Events, :run, 1, [file: ~c"test.exs", line: 10]}
    ]

    normalized = Exception.format(:error, %RuntimeError{message: "user 1 not found"}, [])

    assert SimilarityId.components(:error, normalized, stacktrace) ==
             {"RuntimeError", TowerWeb.DB.Events, :run, 1, ~c"test.exs", 10}
  end

  test "non-:error kinds use the kind atom directly, plus the host-app frame" do
    stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {TowerWeb.DB.Events, :run, 1, [file: ~c"test.exs", line: 10]}
    ]

    normalized_exit = Exception.format(:exit, "boom", [])

    assert SimilarityId.components(:exit, normalized_exit, stacktrace) ==
             {:exit, TowerWeb.DB.Events, :run, 1, ~c"test.exs", 10}
  end

  test "non-:error kinds collapse to just the kind atom when there's no stacktrace frame" do
    normalized_throw = Exception.format(:throw, "boom", [])

    assert SimilarityId.components(:throw, normalized_throw, nil) == {:throw}
  end

  test ":error kind collapses to just the exception module name when there's no stacktrace frame" do
    normalized_reason = Exception.format(:error, %RuntimeError{message: "boom"}, [])

    assert SimilarityId.components(:error, normalized_reason, nil) == {"RuntimeError"}
  end
end
