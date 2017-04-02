defmodule Blackjack.Deck do
  @type t :: [card]
  @type card :: %{suit: suit, rank: rank}
  @type suit :: :spades | :hearts | :diamonds | :clubs
  @type rank :: 2..10 | :jack | :queen | :king | :ace

  @cards (
    for suit <- [:spades, :hearts, :diamonds, :clubs],
        rank <- [2, 3, 4, 5, 6, 7, 8, 9, 10, :jack, :queen, :king, :ace],
      do: %{suit: suit, rank: rank}
  )


  @spec shuffled() :: t
  def shuffled(), do:
    Enum.shuffle(@cards)

  @spec take(t) :: {:ok, card, t} | {:error, :empty}
  def take([card | rest]), do:
    {:ok, card, rest}
  def take([]), do:
    {:error, :empty}
end
