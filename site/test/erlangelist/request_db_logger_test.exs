defmodule Erlangelist.RequestDbLoggerTest do
  use ExUnit.Case

  alias Erlangelist.RequestDbLogger

  setup_all do
    run_query("delete from request_log where user_agent=$1", ["test_browser"])
    :ok
  end

  test "request logging" do
    true = :gproc.reg({:p, :l, RequestDbLogger})

    RequestDbLogger.log(fn -> [
      {"path1", "ip1", "country1", "referer1", "test_browser"}
    ] end)
    assert_receive(:inserted)

    RequestDbLogger.log(fn -> [
      {"path2", "ip2", "country2", "referer2", "test_browser"},
      {"path3", "ip3", "country3", "referer3", "test_browser"},
      {"path4", "ip4", "country4", "referer4", "test_browser"},
      {"path5", "ip5", "country5", "referer5", "test_browser"}
    ] end)
    assert_receive(:inserted)
    refute_receive(:inserted)

    assert(
      {:ok, %{rows: [
        [_, "path1", "ip1", "country1", "referer1", "test_browser", _],
        [_, "path2", "ip2", "country2", "referer2", "test_browser", _],
        [_, "path3", "ip3", "country3", "referer3", "test_browser", _],
        [_, "path4", "ip4", "country4", "referer4", "test_browser", _],
        [_, "path5", "ip5", "country5", "referer5", "test_browser", _]
      ]}} =
      run_query(
        "select * from request_log where user_agent=$1 order by path",
        ["test_browser"]
      )
    )
  end

  defp run_query(query, params) do
    {:ok, _result} =
      Ecto.Adapters.SQL.query(Erlangelist.Repo, query, params)
  end
end