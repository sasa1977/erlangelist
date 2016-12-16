defmodule BufferTest do
  use ExUnit.Case

  for mod <- [Buffer.Queue, Buffer.Ets] do
    @mod mod

    test "#{@mod} empty buffer", do:
      assert @mod.new(1) |> @mod.size() == 0

    test "#{@mod} push an item" do
      buffer = @mod.new(1) |> @mod.push(1)
      assert @mod.size(buffer) == 1
    end

    test "#{@mod} pull an item" do
      buffer = @mod.new(1) |> @mod.push(1)
      assert {:ok, {1, buffer}} = @mod.pull(buffer)
      assert @mod.size(buffer) == 0
    end

    test "#{@mod} pull from an empty buffer" do
      buffer = @mod.new(1)
      assert {:error, :empty} = @mod.pull(buffer)
    end

    test "#{@mod} buffer keeps max size" do
      buffer = @mod.new(2) |> @mod.push(1) |> @mod.push(2) |> @mod.push(3)
      assert @mod.size(buffer) == 2
    end

    test "#{@mod} older items are overwritten" do
      buffer = @mod.new(2) |> @mod.push(1) |> @mod.push(2) |> @mod.push(3)
      assert {:ok, {2, buffer}} = @mod.pull(buffer)
      assert {:ok, {3, _buffer}} = @mod.pull(buffer)
    end
  end
end
