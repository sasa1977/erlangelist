-- Simple test wrk script. Run as:
--   wrk --latency -t100 -c100 -d60s --timeout 1000 -s wrk.lua "http://IP"

wrk.method = "GET"
wrk.path = "/privacy_policy.html"
