defmodule TowerWeb.Live.StacktraceFormatter do
  def last_stacktrace_line(nil), do: nil
  def last_stacktrace_line([]), do: nil

  def last_stacktrace_line(stacktrace) when is_list(stacktrace) do
    stacktrace
    |> List.first()
    |> format_mfa_entry()
  end

  def last_stacktrace_line(_stacktrace), do: nil

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    arity = if is_list(arity_or_args), do: length(arity_or_args), else: arity_or_args
    Exception.format_mfa(module, function, arity)
  end
end
