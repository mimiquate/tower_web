defmodule TowerWeb.Live.StacktraceFormatter do
  require Logger

  def host_otp_app do
    case Application.fetch_env(:tower_web, :otp_app) do
      {:ok, otp_app} when is_atom(otp_app) ->
        otp_app

      {:ok, other} ->
        raise ArgumentError,
              "expected :tower_web, :otp_app to be an atom, got: #{inspect(other)}"

      :error ->
        Logger.warning(
          "[TowerWeb.DB] :tower_web, :otp_app is not configured - grouping cannot identify host-app stacktrace frames"
        )

        nil
    end
  end

  def last_stacktrace_line(stacktrace, host_otp_app \\ nil)

  def last_stacktrace_line(nil, _host_otp_app), do: nil
  def last_stacktrace_line([], _host_otp_app), do: nil

  def last_stacktrace_line(stacktrace, host_otp_app) when is_list(stacktrace) do
    stacktrace |> pick_frame(host_otp_app) |> format_mfa_entry()
  end

  def last_stacktrace_line(_stacktrace, _host_otp_app), do: nil

  @doc """
  Picks the closest frame belonging to `host_otp_app`, falling back to the first
  frame otherwise. Anonymous-function frames (3-tuples) are filtered out first, since
  neither `host_app_entry?/2` nor MFA formatting can handle that shape.
  """
  def pick_frame(stacktrace, host_otp_app) when is_list(stacktrace) do
    frames = Enum.filter(stacktrace, &match?({_, _, _, _}, &1))
    Enum.find(frames, &host_app_entry?(&1, host_otp_app)) || List.first(frames)
  end

  def pick_frame(_stacktrace, _host_otp_app), do: nil

  def host_app_entry?(_entry, nil), do: false

  def host_app_entry?({module, _function, _arity_or_args, _location}, host_otp_app) do
    match?({:ok, ^host_otp_app}, :application.get_application(module))
  end

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    arity = if is_list(arity_or_args), do: length(arity_or_args), else: arity_or_args
    Exception.format_mfa(module, function, arity)
  end
end
