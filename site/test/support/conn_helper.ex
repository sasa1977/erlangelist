defmodule Erlangelist.ConnHelper do
  defmacro test_request(
    verb,
    path,
    expected_content_type \\ :html,
    expected_status,
    expected_regex
  ) do
    quote bind_quoted: [
      verb: verb,
      path: path,
      expected_content_type: expected_content_type,
      expected_status: expected_status,
      expected_regex: expected_regex
    ] do
      test "#{verb} #{path}" do
        conn = unquote(verb)(build_conn, unquote(path))
        assert(
          test_response_type(
            conn,
            unquote(expected_status),
            unquote(expected_content_type)
          ) =~ unquote(expected_regex)
        )
      end
    end
  end

  defmacro test_get(
    path,
    expected_content_type \\ :html,
    expected_status,
    expected_regex
  ) do
    quote bind_quoted: [
      path: path,
      expected_status: expected_status,
      expected_content_type: expected_content_type,
      expected_regex: expected_regex
    ] do
      test_request(:get, path, expected_content_type, expected_status, expected_regex)
    end
  end

  def test_response_type(conn, status, expected_content_type) do
    body = Phoenix.ConnTest.response(conn, status)
    _    = Phoenix.ConnTest.response_content_type(conn, expected_content_type)
    body
  end
end
