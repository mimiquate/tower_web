defmodule TowerWeb.DB.Stacktrace do
  @moduledoc """
  Stacktrace-frame logic and display formatting, shared between grouping
  (`TowerWeb.DB.SimilarityId`) and the dashboard UI (`TowerWeb.CoreComponents`).
  """

  def host_otp_app do
    case Application.fetch_env(:tower_web, :otp_app) do
      {:ok, otp_app} when is_atom(otp_app) ->
        otp_app

      {:ok, other} ->
        raise ArgumentError,
              "expected :tower_web, :otp_app to be an atom, got: #{inspect(other)}"

      :error ->
        nil
    end
  end

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

  defp host_app_entry?(_entry, nil), do: false

  defp host_app_entry?({module, _function, _arity_or_args, _location}, host_otp_app) do
    match?({:ok, ^host_otp_app}, :application.get_application(module))
  end

  @doc """
  A stacktrace frame's arity comes either as an integer or as the actual list of
  arguments - normalizes either shape down to a plain integer.
  """
  def normalize_arity(arity_or_args) when is_list(arity_or_args), do: length(arity_or_args)
  def normalize_arity(arity) when is_integer(arity), do: arity

  @doc """
  Formats the closest `host_otp_app` frame (or the first frame otherwise) for
  display, e.g. "MyApp.Worker.perform/1".
  """
  def pick_and_format_last_stacktrace_frame(stacktrace, host_otp_app \\ nil) do
    stacktrace |> pick_frame(host_otp_app) |> format_mfa_entry()
  end

  defp format_mfa_entry(nil), do: nil

  defp format_mfa_entry({module, function, arity_or_args, _location}) do
    Exception.format_mfa(module, function, normalize_arity(arity_or_args))
  end
end
