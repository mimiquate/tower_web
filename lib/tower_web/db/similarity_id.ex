defmodule TowerWeb.DB.SimilarityId do
  @moduledoc """
  Computes the grouping key used to bucket events into issues.

  Keys on kind/exception-module plus the closest host-app stacktrace line
  (module, function, arity, file, line) - no message/reason content at all.
  """

  alias TowerWeb.Live.StacktraceFormatter

  def compute(kind, normalized_reason, stacktrace) do
    kind |> components(normalized_reason, stacktrace) |> :erlang.phash2()
  end

  def components(kind, normalized_reason, stacktrace) do
    build(kind_or_module(kind, normalized_reason), stacktrace)
  end

  defp build(kind_or_module, stacktrace) do
    case StacktraceFormatter.pick_frame(stacktrace, StacktraceFormatter.host_otp_app()) do
      nil ->
        {kind_or_module}

      {module, function, arity_or_args, opts} ->
        {
          kind_or_module,
          module,
          function,
          normalize_arity(arity_or_args),
          opts[:file],
          opts[:line]
        }
    end
  end

  defp kind_or_module(:error, normalized_reason) when is_binary(normalized_reason) do
    case Regex.run(~r/^\*\* \(([^)]+)\)/, normalized_reason) do
      [_, module_name] -> module_name
      nil -> :unknown
    end
  end

  defp kind_or_module(kind, _normalized_reason), do: kind

  defp normalize_arity(arity_or_args) when is_list(arity_or_args), do: length(arity_or_args)
  defp normalize_arity(arity) when is_integer(arity), do: arity
end
