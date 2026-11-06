defmodule TowerWeb.Live.StacktraceFormatter do
  alias TowerWeb.DB.StacktraceFrame

  def last_stacktrace_line(stacktrace, host_otp_app \\ nil)

  def last_stacktrace_line(nil, _host_otp_app), do: nil
  def last_stacktrace_line([], _host_otp_app), do: nil

  def last_stacktrace_line(stacktrace, host_otp_app) when is_list(stacktrace) do
    stacktrace |> StacktraceFrame.pick_frame(host_otp_app) |> format_mfa_entry()
  end

  def last_stacktrace_line(_stacktrace, _host_otp_app), do: nil

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    Exception.format_mfa(module, function, StacktraceFrame.normalize_arity(arity_or_args))
  end
end
