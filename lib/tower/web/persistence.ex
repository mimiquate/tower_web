defmodule Tower.Web.Persistence do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def insert(%Tower.Web.Event{} = event) do
    Agent.update(__MODULE__, fn events -> [event | events] end)
  end

  def get do
    Agent.get(__MODULE__, & &1)
  end
end
