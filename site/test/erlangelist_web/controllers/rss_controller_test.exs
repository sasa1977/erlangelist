defmodule Erlangelist.RssControllerTest do
  use ErlangelistWeb.ConnCase

  test_get("/rss", :xml, 200, "")
  test_get("/feeds/posts/default", :xml, 200, "")
  test_get("/feeds/posts/foobar", :xml, 200, "")
end
