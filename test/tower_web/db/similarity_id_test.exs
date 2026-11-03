defmodule TowerWeb.DB.SimilarityIdTest do
  use ExUnit.Case, async: true

  alias TowerWeb.DB.SimilarityId

  test "error kind resolves to the exception module name and the closest frame, regardless of message content" do
    stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {TowerWeb.DB.Events, :run, 1, [file: ~c"test.exs", line: 10]}
    ]

    normalized1 = Exception.format(:error, %RuntimeError{message: "user 1 not found"}, [])
    normalized2 = Exception.format(:error, %RuntimeError{message: "user 2 not found"}, [])

    # :error resolves to the exception module name (not the :error atom itself), and
    # picks the closest frame belonging to this (host) app.
    assert SimilarityId.components(:error, normalized1, stacktrace) ==
             {"RuntimeError", TowerWeb.DB.Events, :run, 1, ~c"test.exs", 10}

    # differing message content doesn't change the key.
    assert SimilarityId.compute(:error, normalized1, stacktrace) ==
             SimilarityId.compute(:error, normalized2, stacktrace)
  end

  test "a genuinely different call site produces a different similarity_id" do
    stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {TowerWeb.DB.Events, :run, 1, [file: ~c"test.exs", line: 10]}
    ]

    other_stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {TowerWeb.DB.Events, :other_fun, 1, [file: ~c"test.exs", line: 20]}
    ]

    normalized_reason = Exception.format(:error, %RuntimeError{message: "same message"}, [])

    refute SimilarityId.compute(:error, normalized_reason, stacktrace) ==
             SimilarityId.compute(:error, normalized_reason, other_stacktrace)
  end

  test "same stacktrace and message, but :exit/:throw use the kind atom instead of a module name" do
    stacktrace = [{TowerWeb.DB.Events, :run, 1, [file: ~c"test.exs", line: 10]}]

    normalized_exit = Exception.format(:exit, "boom", [])
    normalized_throw = Exception.format(:throw, "boom", [])

    assert SimilarityId.components(:exit, normalized_exit, stacktrace) ==
             {:exit, TowerWeb.DB.Events, :run, 1, ~c"test.exs", 10}

    assert SimilarityId.components(:throw, normalized_throw, stacktrace) ==
             {:throw, TowerWeb.DB.Events, :run, 1, ~c"test.exs", 10}

    refute SimilarityId.compute(:exit, normalized_exit, stacktrace) ==
             SimilarityId.compute(:throw, normalized_throw, stacktrace)
  end

  test "falls back to the first frame when none belong to the host app, vs. a kind_or_module-only key with no frames at all" do
    normalized_reason = Exception.format(:error, %RuntimeError{message: "boom"}, [])

    stacktrace = [
      {:some_library_module, :internal_fun, 2, [file: ~c"lib.ex", line: 5]},
      {:another_library_module, :other_fun, 1, [file: ~c"other_lib.ex", line: 9]}
    ]

    assert SimilarityId.components(:error, normalized_reason, stacktrace) ==
             {"RuntimeError", :some_library_module, :internal_fun, 2, ~c"lib.ex", 5}

    assert SimilarityId.components(:error, normalized_reason, nil) == {"RuntimeError"}

    refute SimilarityId.compute(:error, normalized_reason, stacktrace) ==
             SimilarityId.compute(:error, normalized_reason, nil)
  end
end
