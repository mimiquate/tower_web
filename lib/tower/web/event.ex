defmodule Tower.Web.Event do
  # TODO: better with typespecs
  defstruct [
    :timestamp, # Unix epoch non negative integer
    :severity, # One of eight severity levels defined in RFC 5424
    :kind,
    :message, # String
    :exception, # Elixir Exception
    :stacktrace # List
  ]
end
