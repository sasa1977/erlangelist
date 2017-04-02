defmodule Blackjack.Hand do
  alias __MODULE__

  defstruct [:cards, :score]

  @type t :: %Hand{cards: [Blackjack.Deck.card], score: nil | 4..21}


  @spec new() :: t
  def new(), do:
    %Hand{cards: [], score: nil}

  @spec deal(t, Blackjack.Deck.card) :: {:ok | :busted, t}
  def deal(hand, card) do
    cards = [card | hand.cards]

    {result, new_score} =
      case Enum.reject([score(cards, :soft), score(cards, :hard)], &(&1 > 21)) do
        [] -> {:busted, nil}
        [best_score | _] -> {:ok, best_score}
      end

    {result, %Hand{hand | cards: cards, score: new_score}}
  end


  defp score(cards, type), do:
    cards
    |> Stream.map(&value(&1.rank, type))
    |> Enum.sum()

  defp value(num, _) when num in 2..10, do: num
  defp value(face, _) when face in [:jack, :queen, :king], do: 10
  defp value(:ace, :hard), do: 1
  defp value(:ace, :soft), do: 11
end
