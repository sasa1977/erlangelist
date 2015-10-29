defmodule Erlangelist.RequestDbLoggerTest do
  use ExUnit.Case

  alias Erlangelist.RequestDbLogger

  test "request logging" do
    true = :gproc.reg({:p, :l, RequestDbLogger})

    run_query("delete from request_log where user_agent=$1", ["db_rq_test_1"])

    RequestDbLogger.log(fn -> [
      {"path1", "ip1", "country1", "referer1", "db_rq_test_1"}
    ] end)
    assert_receive(:inserted)

    RequestDbLogger.log(fn -> [
      {"path2", "ip2", "country2", "referer2", "db_rq_test_1"},
      {"path3", "ip3", "country3", "referer3", "db_rq_test_1"},
      {"path4", "ip4", "country4", "referer4", "db_rq_test_1"},
      {"path5", "ip5", "country5", "referer5", "db_rq_test_1"}
    ] end)
    assert_receive(:inserted)
    refute_receive(:inserted)

    assert(
      %{rows: [
        [_, "path1", "ip1", "country1", "referer1", "db_rq_test_1", _],
        [_, "path2", "ip2", "country2", "referer2", "db_rq_test_1", _],
        [_, "path3", "ip3", "country3", "referer3", "db_rq_test_1", _],
        [_, "path4", "ip4", "country4", "referer4", "db_rq_test_1", _],
        [_, "path5", "ip5", "country5", "referer5", "db_rq_test_1", _]
      ]} =
      run_query(
        "select * from request_log where user_agent=$1 order by path",
        ["db_rq_test_1"]
      )
    )
  end

  test "archive" do
    true = :gproc.reg({:p, :l, RequestDbLogger})

    run_query("delete from request_log where user_agent=$1", ["db_rq_test_2"])

    RequestDbLogger.log(fn ->
      Enum.map(1..30, &{"path#{&1}", "ip#{&1}", "country#{&1}", "referer#{&1}", "db_rq_test_2"})
    end)
    assert_receive(:inserted, :timer.seconds(1))

    %{num_rows: 30, rows: rows} = run_query(
      "select id from request_log where user_agent=$1 order by id asc",
      ["db_rq_test_2"]
    )

    rows
    |> Stream.with_index
    |> Enum.each(fn({[id], index}) ->
        %{num_rows: 1} = run_query("
          update request_log
          set created_at=created_at - interval '#{30 - index} days'
          where id=$1", [id])
       end)

    run_query("delete from request_log_archive where user_agent=$1", ["db_rq_test_2"])

    # Check cleanup
    RequestDbLogger.archive_logs
    check_archive

    # Check repeated cleanup
    RequestDbLogger.archive_logs
    check_archive

    # Check cleanup of the archive
    run_query(
      "
        update request_log_archive
        set created_at=current_date - interval '6 months 1 day'
        where user_agent=$1
      ",
      ["db_rq_test_2"]
    )
    RequestDbLogger.archive_logs

    assert %{rows: [[0]]} =
      run_query("select count(*) from request_log_archive where user_agent=$1", ["db_rq_test_2"])
  end

  defp check_archive do
    assert %{rows: [[7]]} =
      run_query("
        select count(*) from request_log
        where user_agent=$1
        and created_at >= current_date - interval '7 days'",
        ["db_rq_test_2"]
      )

    assert %{rows: [[0]]} =
      run_query("
        select count(*) from request_log
        where user_agent=$1
        and created_at < current_date - interval '7 days'",
        ["db_rq_test_2"]
      )

    assert %{rows: [[0]]} =
      run_query("
        select count(*) from request_log_archive
        where user_agent=$1
        and created_at >= current_date - interval '7 days'",
        ["db_rq_test_2"]
      )

    assert %{rows: [[23]]} =
      run_query("
        select count(*) from request_log_archive
        where user_agent=$1
        and created_at < current_date - interval '7 days'",
        ["db_rq_test_2"]
      )
  end

  defp run_query(query, params) do
    {:ok, result} =
      Ecto.Adapters.SQL.query(Erlangelist.Repo, query, params)
    result
  end
end