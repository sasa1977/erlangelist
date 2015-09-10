defmodule Erlangelist.RssControllerTest do
  use Erlangelist.ConnCase

  test_get "/rss", :xml, 200, ""
end
