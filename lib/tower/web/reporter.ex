defmodule Tower.Web.Reporter do
  @behaviour Tower.Reporter

  @impl true
  def report_exception(exception, stacktrace, _metadata \\ %{})
      when is_exception(exception) and is_list(stacktrace) do
    %Tower.Web.Event{
      timestamp: now(),
      severity: :error,
      message: Exception.message(exception),
      exception: exception,
      stacktrace: stacktrace
    }
    |> Tower.Web.Persistence.insert()
  end

  @impl true
  def report_exit(reason, stacktrace, _metadata \\ %{}) when is_list(stacktrace) do
    %Tower.Web.Event{
      timestamp: now(),
      severity: :error,
      kind: :exit,
      message: reason,
      stacktrace: stacktrace
    }
    |> Tower.Web.Persistence.insert()
  end

  @impl true
  def report_throw(reason, stacktrace, _metadata \\ %{}) when is_list(stacktrace) do
    %Tower.Web.Event{
      timestamp: now(),
      severity: :error,
      kind: :throw,
      message: reason,
      stacktrace: stacktrace
    }
    |> Tower.Web.Persistence.insert()
  end

  @impl true
  def report_message(severity, message, _metadata \\ %{}) when is_atom(severity) and is_binary(message) do
    %Tower.Web.Event{
      timestamp: now(),
      severity: severity,
      message: message
    }
    |> Tower.Web.Persistence.insert()
  end

  defp now do
    DateTime.utc_now() |> DateTime.to_unix()
  end
end
