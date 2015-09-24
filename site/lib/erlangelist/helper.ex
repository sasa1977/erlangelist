defmodule Erlangelist.Helper do
  def ip_string({x,y,z,w}), do: "#{x}.#{y}.#{z}.#{w}"
  def ip_string(_), do: nil
end