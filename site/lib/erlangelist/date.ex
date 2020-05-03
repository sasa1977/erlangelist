defmodule Erlangelist.Date do
  @callback utc_today :: Date.t()

  @module if Mix.env() == :test, do: Erlangelist.Date.Mock, else: Date

  def utc_today, do: @module.utc_today

  def from_yyyymmdd!(<<y::binary-size(4), m::binary-size(2), d::binary-size(2)>>),
    do: Date.from_iso8601!(Enum.join([y, m, d], "-"))
end

if Mix.env() == :test do
  Mox.defmock(Erlangelist.Date.Mock, for: Erlangelist.Date)
end
