defmodule Demo do
  def run, do:
    start_round(
      :"round_#{:erlang.unique_integer()}",
      Enum.map(1..5, &:"player_#{&1}")
    )

  defp start_round(round_id, player_ids) do
    Demo.AutoPlayer.Server.start_link(round_id, player_ids)

    Blackjack.RoundServer.start_playing(
      round_id,
      Enum.map(player_ids, &Demo.AutoPlayer.Server.player_spec(round_id, &1))
    )
  end
end

defmodule Demo.AutoPlayer.Server do
  use GenServer
  @behaviour Blackjack.PlayerNotifier

  alias Demo.AutoPlayer


  def start_link(round_id, player_ids), do:
    GenServer.start_link(__MODULE__, {round_id, player_ids}, name: round_id)

  def player_spec(round_id, player_id), do:
    %{id: player_id, callback_mod: __MODULE__, callback_arg: round_id}


  @doc false
  def deal_card(round_id, player_id, card), do:
    GenServer.call(round_id, {:deal_card, player_id, card})

  @doc false
  def move(round_id, player_id), do:
    GenServer.call(round_id, {:move, player_id})

  @doc false
  def busted(round_id, player_id), do:
    GenServer.call(round_id, {:busted, player_id})

  @doc false
  def unauthorized_move(round_id, player_id), do:
    GenServer.call(round_id, {:unauthorized_move, player_id})

  @doc false
  def winners(round_id, player_id, winners) do
    if Enum.member?(winners, player_id), do:
      GenServer.call(round_id, {:won, player_id})

    :ok
  end

  @doc false
  def init({round_id, player_ids}), do:
    {:ok, %{
      round_id: round_id,
      players: player_ids |> Enum.map(&{&1, AutoPlayer.new()}) |> Enum.into(%{})
    }}

  @doc false
  def handle_call({:move, player_id}, from, state) do
    GenServer.reply(from, :ok)
    IO.puts("#{player_id}: thinking ...")
    next_move = AutoPlayer.next_move(state.players[player_id])
    IO.puts("#{player_id}: #{next_move}")
    if next_move == :stand, do: IO.puts ""
    Blackjack.RoundServer.move(state.round_id, player_id, next_move)
    {:noreply, state}
  end
  def handle_call({:deal_card, player_id, card}, _from, state) do
    IO.puts "#{player_id}: #{card.rank} of #{card.suit}"
    {:reply, :ok, update_in(state.players[player_id], &AutoPlayer.deal(&1, card))}
  end
  def handle_call({:won, player_id}, _from, state) do
    IO.puts("#{player_id}: won")
    {:reply, :ok, state}
  end
  def handle_call({:busted, player_id}, _from, state) do
    IO.puts("#{player_id}: busted")
    IO.puts ""
    {:reply, :ok, state}
  end
end

defmodule Demo.AutoPlayer do
  alias Blackjack.Hand

  def new(), do: Hand.new()

  def deal(hand, card) do
    {_, hand} = Hand.deal(hand, card)
    hand
  end

  def next_move(hand) do
    :timer.sleep(:rand.uniform(:timer.seconds(2)))

    if :rand.uniform(11) + 10 < hand.score do
      :stand
    else
      :hit
    end
  end
end
