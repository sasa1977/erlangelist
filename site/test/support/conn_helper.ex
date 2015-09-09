defmodule Erlangelist.ConnHelper do
  defmacro test_request(verb, path, expected_status, expected_regex) do
    quote bind_quoted: [
      verb: verb,
      path: path,
      expected_status: expected_status,
      expected_regex: expected_regex
    ] do
      test "#{verb} #{path}" do
        conn = unquote(verb)(conn, unquote(path))
        assert html_response(conn, unquote(expected_status)) =~ unquote(expected_regex)
      end
    end
  end

  defmacro test_get(path, expected_status, expected_regex) do
    quote bind_quoted: [
      path: path,
      expected_status: expected_status,
      expected_regex: expected_regex
    ] do
      test_request(:get, path, expected_status, expected_regex)
    end
  end
end