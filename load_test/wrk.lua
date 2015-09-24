-- Simple test wrk script. Run as:
--   wrk -t10 -c10 -d60s --timeout 1000 -s wrk.lua "http://IP"

requests = {
  "/article/outside_elixir",
  "/article/tallakt_macros",
  "/article/beyond_taskasync",
  "/",
  "/2015/07/beyond-taskasync.html",
  "/2013/01/teaching-orthogonal-programming.html",
  "/invalid_url",
  "/article/invalid_article"
}

length = #requests

request = function()
  wrk.headers["Cookie"] = "cookies=true"
  wrk.method = "GET"
  return wrk.format(nil, requests[math.random(length)])
end