defmodule Blackjack.HandTest do
  use ExUnit.Case, async: true

  alias Blackjack.Hand

  test "not busted" do
    assert {:ok, hand} = hand([2])
    assert hand.score == 2
  end

  test "busted" do
    assert {:busted, hand} = hand([10, 10, 10])
    assert hand.score == nil
  end

  test "hard not busted" do
    assert {:ok, hand} = hand([10, 10, :ace])
    assert hand.score == 21
  end

  test "hard not busted (two aces)" do
    assert {:ok, hand} = hand([:ace, :ace])
    assert hand.score == 12
  end

  test "hard busted", do:
    assert {:busted, _} = hand([10, 10, :ace, 2])


  defp hand(ranks), do:
    deal_cards(Hand.new(), Enum.map(ranks, &card/1))

  defp deal_cards(hand, [card]), do:
    Hand.deal(hand, card)
  defp deal_cards(hand, [card | remaining_cards]) do
    {:ok, hand} = Hand.deal(hand, card)
    deal_cards(hand, remaining_cards)
  end

  defp card(rank), do:
    %{rank: rank, suit: :hearts}
end
