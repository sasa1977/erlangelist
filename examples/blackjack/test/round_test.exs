defmodule Blackjack.RoundTest do
  use ExUnit.Case, async: true

  alias Blackjack.Round

  defmacrop notify_player_instruction(player_id, data) do
    quote do
      {:notify_player, unquote(player_id), unquote(data)}
    end
  end

  test "initial play" do
    assert {deals, _} = Round.start([:a, :b], deck([2, 3, 4, 5]))
    assert deals == [
      notify_player_instruction(:a, {:deal_card, card(2)}),
      notify_player_instruction(:a, {:deal_card, card(3)}),
      notify_player_instruction(:a, :move),
    ]
  end

  test "stand moves to next player" do
    {_, round} = Round.start([:a, :b, :c])
    assert {instructions, round} = Round.move(round, :a, :stand)
    assert Enum.member?(instructions, notify_player_instruction(:b, :move))

    assert {instructions, round} = Round.move(round, :b, :stand)
    assert Enum.member?(instructions, notify_player_instruction(:c, :move))

    assert {instructions, _} = Round.move(round, :c, :stand)
    assert Enum.any?(instructions, &match?(notify_player_instruction(:a, {:winners, _}), &1))
  end

  test "busting moves to next player" do
    {_, round} = Round.start([:a, :b, :c], deck([10, 10, 10, 10, 10, 10, 10, 10, 10]))
    assert {instructions, round} = Round.move(round, :a, :hit)
    assert Enum.member?(instructions, notify_player_instruction(:b, :move))

    assert {instructions, round} = Round.move(round, :b, :hit)
    assert Enum.member?(instructions, notify_player_instruction(:c, :move))

    assert {instructions, _} = Round.move(round, :c, :hit)
    assert Enum.any?(instructions, &match?(notify_player_instruction(:a, {:winners, _}), &1))
  end

  test "taking a hit" do
    {_, round} = Round.start([:a], deck([2, 3, 4, 5, 6]))
    assert {[
      notify_player_instruction(:a, {:deal_card, card}),
      notify_player_instruction(:a, :move)
    ], _round} = Round.move(round, :a, :hit)
    assert card == card(4)
  end

  test "taking a stand" do
    {_, round} = Round.start([:a], deck([2, 3, 4, 5, 6]))
    assert {[notify_player_instruction(:a, {:winners, [:a]})], _round} = Round.move(round, :a, :stand)
  end

  test "busting" do
    {_, round} = Round.start([:a], deck([10, 10, 10]))
    assert {instructions, _round} = Round.move(round, :a, :hit)
    assert Enum.member?(instructions, notify_player_instruction(:a, :busted))
    assert Enum.member?(instructions, notify_player_instruction(:a, {:winners, []}))
  end

  test "one winner" do
    {_, round} = Round.start([:a, :b], deck([2, 3, 4, 5]))
    {_, round} = Round.move(round, :a, :stand)
    assert {instructions, _} = Round.move(round, :b, :stand)
    assert Enum.member?(instructions, notify_player_instruction(:a, {:winners, [:b]}))
  end

  test "multiple winners" do
    {_, round} = Round.start([:a, :b, :c], deck([3, 3, 3, 3, 2, 2]))
    {_, round} = Round.move(round, :a, :stand)
    {_, round} = Round.move(round, :b, :stand)
    assert {[
      notify_player_instruction(:a, {:winners, [:a, :b]}),
      notify_player_instruction(:b, {:winners, [:a, :b]}),
      notify_player_instruction(:c, {:winners, [:a, :b]})
    ], _} = Round.move(round, :c, :stand)
  end

  test "unauthorized move" do
    {_, round} = Round.start([:a, :b, :c])
    assert {instructions, _} = Round.move(round, :b, :stand)
    assert Enum.member?(instructions, notify_player_instruction(:b, :unauthorized_move))
  end

  test "more players than cards in a single deck" do
    player_ids = Enum.map(1..100, &:"player_#{&1}")
    {instructions, round} = Round.start(player_ids)
    {instructions, _} =
      Enum.reduce(player_ids, {instructions, round},
        fn(player_id, {_, round}) -> Round.move(round, player_id, :stand) end
      )
    assert Enum.any?(instructions, &match?(notify_player_instruction(_, {:winners, _}), &1))
  end

  def deck(ranks), do:
    Enum.map(ranks, &card/1)

  defp card(rank), do:
    %{rank: rank, suit: :hearts}
end
