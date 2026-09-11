defmodule TowerWeb.Live.StacktraceFormatter do
  def last_stacktrace_line(stacktrace, host_otp_app \\ nil)

  def last_stacktrace_line(nil, _host_otp_app), do: nil
  def last_stacktrace_line([], _host_otp_app), do: nil

  def last_stacktrace_line(stacktrace, host_otp_app) when is_list(stacktrace) do
    stacktrace
    |> Enum.find(&host_app_entry?(&1, host_otp_app))
    |> Kernel.||(List.first(stacktrace))
    |> format_mfa_entry()
  end

  def last_stacktrace_line(_stacktrace, _host_otp_app), do: nil

  defp host_app_entry?(_entry, nil), do: false

  defp host_app_entry?({module, _function, _arity_or_args, _location}, host_otp_app) do
    match?({:ok, ^host_otp_app}, :application.get_application(module))
  end

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    arity = if is_list(arity_or_args), do: length(arity_or_args), else: arity_or_args
    Exception.format_mfa(module, function, arity)
  end
end
