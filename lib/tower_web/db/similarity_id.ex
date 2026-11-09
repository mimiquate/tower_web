defmodule TowerWeb.DB.SimilarityId do
  @moduledoc """
  Computes the grouping key used to bucket events into issues.

  Keys on kind/exception-module plus a stacktrace line (module, function, arity,
  file, line) - no message/reason content at all. The line used is the closest
  host-app frame if one can be identified; otherwise it falls back to the first
  frame regardless of which application it belongs to, or is omitted entirely if
  the stacktrace has no resolvable frame at all.
  """

  alias TowerWeb.DB.Stacktrace

  def compute(kind, normalized_reason, stacktrace) do
    components(kind, normalized_reason, stacktrace) |> :erlang.phash2()
  end

  def components(kind, normalized_reason, stacktrace) do
    build(kind_or_module(kind, normalized_reason), stacktrace)
  end

  defp build(kind_or_module, stacktrace) do
    case Stacktrace.pick_frame(stacktrace, Stacktrace.host_otp_app()) do
      nil ->
        {kind_or_module}

      {module, function, arity_or_args, opts} ->
        {
          kind_or_module,
          module,
          function,
          Stacktrace.normalize_arity(arity_or_args),
          opts[:file],
          opts[:line]
        }
    end
  end

  defp kind_or_module(:error, normalized_reason) when is_binary(normalized_reason) do
    # Exception.format/3 always normalizes :error reasons into an exception struct
    # first, so the rendered banner is always "** (Module) ...".
    [_, module_name] = Regex.run(~r/^\*\* \(([^)]+)\)/, normalized_reason)
    module_name
  end

  defp kind_or_module(kind, _normalized_reason), do: kind
end
