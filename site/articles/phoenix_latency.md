Recently there were a couple of questions on [Elixir Forum](http://elixirforum.com) about observed performance of a simple Phoenix based server (see [here](http://elixirforum.com/t/evaluating-elixir-phoenix-for-a-web-scale-performance-critical-application/832) for example). People reported some unspectacular numbers, such as a throughput of only a few thousand requests per second and a latency in the area of a few tens of milliseconds.

While such results are decent, a simple server should be able to give us better numbers. In this post I'll try to demonstrate how you can easily get some more promising results. I should immediately note that this is going to be a shallow experiment. I won't go into deeper analysis, and I won't deal with tuning of VM or OS parameters. Instead, I'll just pick a few low-hanging fruits, and rig the load test by providing the input which gives me good numbers. The point of this post is to demonstrate that it's fairly easy to get (near) sub-ms latencies with a decent throughput. Benching a more real-life like scenario is more useful, but also requires a larger effort.


## Building the server

I'm going to load test a simple JSON API:

```bash
$ curl -X POST \
    -H "Content-Type: application/json" \
    -d '{"a": 1, "b": 2}' \
    localhost:4000/api/sum

{"result":3}
```

It's not spectacular but it will serve the purpose. The server code will read and decode the body, then perform the computation, and produce an encoded JSON response. This makes the operation mostly CPU bound, so under load I expect to see CPU usage near 100%.

So let's build the server. First, I'll create a basic mix skeleton:

```
$ mix phoenix.new bench_phoenix --no-ecto --no-brunch --no-html
```

I don't need ecto, brunch, or html support, since I'll be exposing only a simple API interface.

Next, I need to implement the controller:

```elixir
defmodule BenchPhoenix.ApiController do
  use BenchPhoenix.Web, :controller

  def sum(conn, %{"a" => a, "b" => b}) do
    json(conn, %{result: a + b})
  end
end
```

And add a route:

```elixir
defmodule BenchPhoenix.Router do
  use BenchPhoenix.Web, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", BenchPhoenix do
    pipe_through :api

    post "/sum", ApiController, :sum
  end
end
```

Now I need to change some settings to make the server perform better. In `prod.exs`, I'll increase the logger level to `:warn`:

```elixir
config :logger, level: :warn
```

By default, the logger level is set to `:info` meaning that each request will be logged. This leads to a lot of logging under load, which will cause the `Logger` to start applying back pressure. Consequently, logging will become a bottleneck, and you can get crappy results. Therefore, when measuring, make sure to avoid logging all requests, either by increasing the logger level in prod, or by changing the log level of the request to `:debug` in your endpoint (with `plug Plug.Logger, log: :debug`).

Another thing I'll change is the value of the `max_keepalive` Cowboy option. This number specifies the maximum number of requests that can be served on a single connection. The default value is 100, meaning that the test would have to open new connections frequently. Increasing this value to something large will allow the test to establish the connections only once and reuse them throughout the entire test. Here's the relevant setting in `prod.exs`:

```elixir
config :bench_phoenix, BenchPhoenix.Endpoint,
  http: [port: 4000,
    protocol_options: [max_keepalive: 5_000_000]
  ],
  url: [host: "example.com", port: 80],
  cache_static_manifest: "priv/static/manifest.json"
```

Notice that I have also hardcoded the `port` setting to `4000` so I don't need to specify it through the environment.

I also need to tell Phoenix to start the server when the system starts:

```elixir
config :bench_phoenix, BenchPhoenix.Endpoint, server: true
```

I plan to run the system as the OTP release. This is a recommended way of running Erlang in production, and it should give me better performance than `iex -S mix`. To make this work, I need to add `exrm` as a dependency:

```elixir
defp deps do
  [..., {:exrm, "~> 1.0"}]
end
```

Finally, I need to setup the load-test script. I'll be using the [wrk tool](https://github.com/wg/wrk), so I'll create the `wrk.lua` script:

```lua
request = function()
  a = math.random(100)
  b = math.random(100)
  wrk.method = "POST"
  wrk.headers["Content-Type"] = "application/json"
  wrk.body = '{"a":' .. a .. ',"b":' .. b .. '}'
  return wrk.format(nil, "/api/sum")
end
```

And that's it! The server is now ready to be load tested. You can find the complete code [here](https://github.com/sasa1977/erlangelist/tree/master/examples/bench_phoenix).

## Running the test

I'll be running tests on my 2011 iMac:

```text
Model Name: iMac
Model Identifier: iMac12,2
Processor Name: Intel Core i7
Processor Speed:  3,4 GHz
Number of Processors: 1
Total Number of Cores:  4
Memory: 8 GB
```

Let's start the OTP release:

```bash
$ MIX_ENV=prod mix do deps.get, compile, release && \
    rel/bench_phoenix/bin/bench_phoenix foreground
```

First, I'll quickly verify that the server works:

```bash
$ curl -X POST \
    -H "Content-Type: application/json" \
    -d '{"a": 1, "b": 2}' \
    localhost:4000/api/sum

{"result":3}
```

And now I'm ready to start the test:

```bash
$ wrk -t12 -c12 -d60s --latency -s wrk.lua "http://localhost:4000"
```

The parameters here are rigged to make the results attractive. I'm using as few connections as needed (the number was chosen after a couple of trial runs) to get close to the server's max capacity. Adding more connections would cause the test to issue more work than the server can cope with, so consequently the latency would suffer. If you're running the test on your own machine, you might need to tweak these numbers a bit to get the best results.

Let's see the output:

```text
Running 1m test @ http://localhost:4000
  12 threads and 12 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   477.31us  123.80us   3.05ms   75.66%
    Req/Sec     2.10k   198.83     2.78k    62.43%
  Latency Distribution
     50%  450.00us
     75%  524.00us
     90%  648.00us
     99%    0.87ms
  1435848 requests in 1.00m, 345.77MB read
Requests/sec:  23931.42
Transfer/sec:      5.76MB
```

I've observed a throughput of ~ 24k requests/sec, with 99th percentile latency below 1ms, and the maximum observed latency at 3.05ms. I also started `htop` and confirmed that all cores were near 100% usage, meaning the system was operating near its capacity.

For good measure, I also ran a 5 minute test, to verify that the results are consistent:

```text
Running 5m test @ http://localhost:4000
  12 threads and 12 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   484.19us  132.26us  12.98ms   76.35%
    Req/Sec     2.08k   204.89     2.80k    70.10%
  Latency Distribution
     50%  454.00us
     75%  540.00us
     90%  659.00us
     99%    0.89ms
  7090793 requests in 5.00m, 1.67GB read
Requests/sec:  23636.11
Transfer/sec:      5.69MB
```

The results seems similar to a 1 minute run, with a bit worrying difference in the maximum latency, which is now 13ms.

It's also worth verifying how the latency is affected when the system is overloaded. Let's use a bit more connections:

```text
$ wrk -t100 -c100 -d1m --latency -s wrk.lua "http://localhost:4000"

Running 1m test @ http://localhost:4000
  100 threads and 100 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    13.40ms   24.24ms 118.92ms   90.16%
    Req/Sec   256.22    196.73     2.08k    74.35%
  Latency Distribution
     50%    4.50ms
     75%    9.35ms
     90%   36.13ms
     99%  100.02ms
  1462818 requests in 1.00m, 352.26MB read
Requests/sec:  24386.51
Transfer/sec:      5.87MB
```

Looking at `htop`, I observed that CPU is fully maxed out, so the system is completely using all the available hardware and operating at its max capacity. Reported latencies are quite larger now, since we're issuing more work than the system can handle on the given machine.

Assuming the code is optimized, the solution could be to scale up and put the system on a more powerful machine, which should restore the latency. I don't have such machine available, so I wasn't able to prove it.

It's also worth considering guarding the system against overloads by making it refuse more work than it can handle. Although that doesn't seem like a perfect solution, it can allow the system to operate within its limits and thus maintain the latency within bounds. This approach would make sense if you have some fix upper bound on the acceptable latency. Accepting requests which can't be served within the given time frame doesn't make much sense, so it's better to refuse them upfront.

## Conclusion

I'd like to stress again that this was a pretty shallow test. The main purpose was to prove that we can get some nice latency numbers with a fairly small amount of effort. The results look promising, especially since they were obtained on my personal box, where both the load tester and the server were running, as well as other applications (mail client, browser, editor, ...).

However, don't be tempted to jump to conclusions too quickly. A more exhaustive test would require a dedicated server, tuning of OS parameters, and playing with the [emulator flags](http://erlang.org/doc/man/erl.html#emu_flags) such as `+K` and `+s`. It's also worth pointing out that synthetic tests can easily be misleading, so be sure to construct an example which resembles the real use case you're trying to solve.
