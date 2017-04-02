defmodule Blackjack.IntegrationTest do
  use ExUnit.Case, async: true
  @behaviour Blackjack.PlayerNotifier

  test "game with two players" do
    {:ok, _} = Blackjack.RoundServer.start_playing(
      :round_1,
      [
        %{id: :player_1, callback_mod: __MODULE__, callback_arg: self()},
        %{id: :player_2, callback_mod: __MODULE__, callback_arg: self()}
      ]
    )

    assert_receive {:player_1, {:deal_card, _card}}
    assert_receive {:player_1, {:deal_card, _card}}
    assert_receive {:player_1, :move}

    hit_until_busted(:round_1, :player_1)

    assert_receive {:player_2, :move}
    assert_receive {:player_2, {:deal_card, _card}}
    assert_receive {:player_2, {:deal_card, _card}}

    Blackjack.RoundServer.move(:round_1, :player_2, :stand)
    assert_receive {:player_1, {:winners, [:player_2]}}
    assert_receive {:player_2, {:winners, [:player_2]}}
    refute_receive _
  end

  defp hit_until_busted(round_id, player_id) do
    Blackjack.RoundServer.move(round_id, player_id, :hit)
    assert_receive {^player_id, {:deal_card, _card}}
    assert_receive {^player_id, move_or_busted}
    case move_or_busted do
      :move -> hit_until_busted(round_id, player_id)
      :busted -> :ok
    end
  end

  def deal_card(test_pid, player_id, card), do:
    send(test_pid, {player_id, {:deal_card, card}})

  def move(test_pid, player_id), do:
    send(test_pid, {player_id, :move})

  def busted(test_pid, player_id), do:
    send(test_pid, {player_id, :busted})

  def unauthorized_move(test_pid, player_id), do:
    send(test_pid, {player_id, :unauthorized_move})

  def winners(test_pid, player_id, winner_ids), do:
    send(test_pid, {player_id, {:winners, winner_ids}})
end
