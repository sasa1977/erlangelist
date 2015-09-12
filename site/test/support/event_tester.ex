defmodule Erlangelist.EventTester do
  use GenEvent

  def handle_event(caller), do: {:ok, caller}

  def handle_event(event, caller) do
    send(caller, {:event, event})
    {:ok, caller}
  end

  def start_listener(event_manager) do
    GenEvent.add_mon_handler(event_manager, __MODULE__, self)
  end
end