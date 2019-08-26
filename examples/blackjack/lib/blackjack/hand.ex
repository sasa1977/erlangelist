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
      case score(cards) do
        score when score > 21 -> {:busted, nil}
        score -> {:ok, score}
      end

    {result, %Hand{hand | cards: cards, score: new_score}}
  end

  defp score(cards) do
    cards
    |> Enum.map(&value/1)
    |> summarize_scores()
  end

  defp value(%{rank: num}) when num in 2..10, do: num
  defp value(%{rank: face}) when face in [:jack, :queen, :king], do: 10
  defp value(%{rank: :ace}), do: 11

  defp summarize_scores(scores)  do
    total = Enum.sum(scores)
    ordered_scores = scores |> Enum.sort() |> Enum.reverse()
    summarize_scores(total, ordered_scores)
  end

  defp summarize_scores(total, [highest | rest]) when total > 21 and highest == 11 do
    summarize_scores([1 | rest])
  end
  defp summarize_scores(total, _), do: total
end
