defmodule Blackjack.PlayerNotifier do
  use GenServer

  alias Blackjack.{Round, RoundServer}

  @callback deal_card(RoundServer.callback_arg, Round.player_id, Blackjack.Deck.card) :: any
  @callback move(RoundServer.callback_arg, Round.player_id) :: any
  @callback busted(RoundServer.callback_arg, Round.player_id) :: any
  @callback winners(RoundServer.callback_arg, Round.player_id, [Round.player_id]) :: any
  @callback unauthorized_move(RoundServer.callback_arg, Round.player_id) :: any


  @spec child_spec(RoundServer.id, [RoundServer.player]) :: Supervisor.Spec.spec
  def child_spec(round_id, players) do
    import Supervisor.Spec

    supervisor(Supervisor,
      [
        Enum.map(players, &worker(__MODULE__, [round_id, &1], [id: {__MODULE__, &1.id}])),
        [strategy: :one_for_one]
      ]
    )
  end

  @spec publish(RoundServer.id, Round.player_id, Round.player_instruction) :: :ok
  def publish(round_id, player_id, player_instruction), do:
    GenServer.cast(service_name(round_id, player_id), {:notify, player_instruction})


  @doc false
  def start_link(round_id, player), do:
    GenServer.start_link(
      __MODULE__,
      {round_id, player},
      name: service_name(round_id, player.id)
    )

  @doc false
  def init({round_id, player}), do:
    {:ok, %{round_id: round_id, player: player}}

  @doc false
  def handle_cast({:notify, player_instruction}, state) do
    {fun, args} = decode_instruction(player_instruction)
    all_args = [state.player.callback_arg, state.player.id | args]
    apply(state.player.callback_mod, fun, all_args)
    {:noreply, state}
  end


  defp service_name(round_id, player_id), do:
    Blackjack.service_name({__MODULE__, round_id, player_id})

  defp decode_instruction({:deal_card, card}), do:
    {:deal_card, [card]}
  defp decode_instruction(:move), do:
    {:move, []}
  defp decode_instruction(:busted), do:
    {:busted, []}
  defp decode_instruction(:unauthorized_move), do:
    {:unauthorized_move, []}
  defp decode_instruction({:winners, player_ids}), do:
    {:winners, [player_ids]}
end
