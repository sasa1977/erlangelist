defmodule SocketDriver.PingChannel do
  use Phoenix.Channel

  def join(_topic, _payload, socket) do
    {:ok, %{"response" => "hello"}, socket}
  end

  def handle_in("ping", _payload, socket) do
    push(socket, "pong", %{})
    {:noreply, socket}
  end
end
