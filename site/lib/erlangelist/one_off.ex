defmodule Erlangelist.OneOff do
  def start_link do
    Task.Supervisor.start_link(name: :one_off)
  end

  def run(fun) do
    Task.Supervisor.start_child(:one_off, fun)
  end
end