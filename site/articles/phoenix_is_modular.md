A few days ago I saw this question on #elixir-lang channel:

> Have any of you had the initial cringe at the number of moving parts Phoenix needs to get you to just "Hello World" ?

Coincidentally, on that same day I received a mail where a developer briefly touched on Phoenix:

> I really like Elixir, but can't seem to find happiness with Phoenix. Too much magic happening there and lots of DSL syntax, diverts from the simplicity of Elixir while not really giving a clear picture of how things work under the hood. For instance, they have endpoints, routers, pipelines, controllers. Can we not simplify endpoints, pipelines and controllers into one thing - say controllers...

I can sympathize with such sentiments. When I first looked at Phoenix, I was myself overwhelmed by the amount of concepts one needs to grasp. But after spending some time with the framework, it started making sense to me, and I began to see the purpose of all these concepts. I quickly became convinced that Phoenix provides reasonable building blocks which should satisfy most typical needs.

Furthermore, [I've learned that Phoenix is actually quite modular](https://twitter.com/sasajuric/status/664570309929000960). This is nice because we can trim it down to our own preferences (though in my opinion that's usually not needed). In fact, it is possible to run a Phoenix powered server without a router, controller, view, and template. In this article I'll show you how, and then I'll provide some tips on learning Phoenix. But first, I'll briefly touch on the relationship between Phoenix and Plug.


## Phoenix and Plug

Phoenix owes its modularity to [Plug](https://github.com/elixir-lang/plug). Many Phoenix abstractions, such as endpoint, router, or controller, are implemented as _plugs_, so let's quickly recap the idea of Plug.

When a request arrives, the Plug library will create a `Plug.Conn` struct (aka _conn_). This struct bundles various fields describing the request (e.g. the IP address of the client, the path, headers, cookies) together with the fields describing the response (e.g. status, body, headers). Once the conn struct is initialized, Plug will call our function to handle the request. The task of our code is to take the conn struct and return the transformed version of it with populated output fields. The Plug library then uses the underlying HTTP library (for example Cowboy) to return the response. There are some fine-print variations to this concept, but they're not relevant for this discussion.

So essentially, our request handler is a function that takes a conn and transforms it. In particular, each function that takes two arguments (a conn and arbitrary options) is called a _plug_. Additionally, a plug can be a module that implements two functions `init/1` which provides the options, and `call/2` which takes a conn and options, and returns the transformed conn.

Request handler can be implemented as a chain of such plugs, with the help of [Plug.Builder](http://hexdocs.pm/plug/Plug.Builder.html). Since a plug is basically a function, your request handler boils down to a chain of functions threading the conn struct. Each function takes a conn, does it's own processing, and produces a transformed version of it. Then the next function in the chain is invoked to do its job.

Each plug in the chain can do various tasks, such as logging (`Plug.Logger`), converting the input (for example `Plug.Head` which transforms a `HEAD` request into `GET`), or producing the output (e.g. `Plug.Static` which serves files from the disk). It is also easy to write your own plugs, for example to authenticate users, or to perform some other custom action. For example, for this site [I implemented a plug which counts visits, measures the processing time, and sends stats to graphite](https://github.com/sasa1977/erlangelist/blob/master/site/web/plugs/visit.ex). Typically, the last function in the chain will be the "core" handler which performs some request-specific processing, such as data manipulation, or some computation, and produces the response.

When it comes to Phoenix, endpoint, router, and controllers are all plugs. Your request arrives to the endpoint which specifies some common plugs (e.g. serving of static files, logging, session handling). By default, the last plug listed in the endpoint is the router where request path is mapped to some controller, which is itself yet another plug in the chain.


## Trimming down Phoenix

Since all the pieces in Phoenix are plugs, and plugs are basically functions, nothing stops you from removing any part out of the chain. The only thing you need for a basic Phoenix web app is the endpoint. Let's see an example. I'll create a simple "Hello World" web server based on Phoenix. This server won't rely on router, controllers, views, and templates.

First, I need to generate a new Phoenix project with `mix phoenix.new simple_server --no-ecto --no-brunch --no-html`. The options specify I want to omit Ecto, Brunch, and HTML views from the generated project. This already makes the generated code thinner than the default version.

There are still some pieces that can be removed, and I've done that in [this commit](https://github.com/sasa1977/erlangelist/commit/964f52eddd01610f729e2bd988e203428291cf82). The most important change is that I've purged all the plugs from the endpoint, reducing it to:

```elixir
defmodule SimpleServer.Endpoint do
  use Phoenix.Endpoint, otp_app: :simple_server
end
```

All requests will end up in an endpoint which does nothing, so every request will result in a 500 error. This is a consequence of removing all the default stuff. There are no routers, controllers, views, or templates anymore, and there's no default behaviour. The "magic" has disappeared and it's up to us to recreate it manually.

Handling a request can now be as simple as:

```elixir
defmodule SimpleServer.Endpoint do
  use Phoenix.Endpoint, otp_app: :simple_server

  plug :render

  def render(conn, _opts) do
    Plug.Conn.send_resp(conn, 200, "Hello World!")
  end
end
```

And there you have it! A Phoenix powered "Hello World" in less than 10 lines of code. Not so bad :-)


## Reusing desired Phoenix pieces

Since Phoenix is modular, it's fairly easy to reintroduce some parts of it if needed. For example, if you want to log requests, you can simply add following plugs to your endpoint:

```elixir
plug Plug.RequestId
plug Plug.Logger
```

If you want to use the Phoenix router, you can add `plug MyRouter` where `MyRouter` is built on top of [Phoenix.Router](http://hexdocs.pm/phoenix/Phoenix.Router.html). Perhaps you prefer the Plug router? Simply implement `MyRouter` as [Plug.Router](http://hexdocs.pm/plug/Plug.Router.html).

Let's see a different example. Instead of shaping strings manually, I'll reuse Phoenix templates support, so I can write EEx templates.

First, I'll create the `web/templates/index.html.eex` file:

```html
<html>
  <body>
    Hello World!
  </body>
</html>
```

Then, relying on [Phoenix.Template](http://hexdocs.pm/phoenix/Phoenix.Template.html), I'll compile all templates from the `web/templates` folder into a single module:

```elixir
defmodule SimpleServer.View do
  use Phoenix.Template, root: "web/templates"
end
```

Now, I can call `SimpleServer.View.render("index.html")` to produce the output string:

```elixir
defmodule SimpleServer.Endpoint do
  use Phoenix.Endpoint, otp_app: :simple_server

  plug :render

  def render(conn, _opts) do
    conn
    |> Plug.Conn.put_resp_content_type("text/html")
    |> Plug.Conn.send_resp(200, SimpleServer.View.render("index.html"))
  end
end
```

Finally, I need to set the encoder for the HTML format in `config.exs`:

```elixir
# config.exs

config :phoenix, :format_encoders, html: Phoenix.HTML.Engine

# ...
```

And that's it! The output is now rendered through a precompiled EEx template. And still, no router, controller, or Phoenix view has been used. You can find the complete solution [here](https://github.com/sasa1977/erlangelist/tree/b31cd0dbcf222bc737d59951157077d8127535aa/examples/simple_server).

It's worth noting that by throwing most of the default stuff out, we also lost many benefits of Phoenix. This simple server doesn't serve static files, log requests, handle sessions, or parse the request body. Live reload also won't work. You can of course reintroduce these features if you need them.


## What's the point?

To be honest, I usually wouldn't recommend this fully sliced-down approach. My impression is that the default code generated with `mix phoenix.new` is a sensible start for most web projects. Sure, you have to spend some time understanding the flow of a request, and roles of endpoint, router, view, and template, but I think it will be worth the effort. At the end of the day, as Chris frequently said, Phoenix aims to provide the "battery included" experience, so the framework is bound to have some inherent complexity. I wouldn't say it's super complex though. You need to take some time to let it sink in, and you're good to go. It's a one off investment, and not a very expensive one.

That being said, if you have simpler needs, or you're overwhelmed by many different Phoenix concepts, throwing some stuff out might help. Hopefully it's now obvious that Phoenix is quite tunable. Once you understand Plug it's fairly easy to grasp how a request is handled in Phoenix. Tweaking the server to your own needs is just a matter of removing the plugs you don't want. In my opinion, this is the evidence of a good and flexible design. All the steps are spelled out for you in your project's code, so everything is explicit and you can tweak it as you please.


## Learning tips

Learning Phoenix is still not a small task, especially if you're new to Elixir and OTP. If your Elixir journey starts with Phoenix, you'll need to learn the new language, adapt to functional programming, understand BEAM concurrency, become familiar with OTP, and learn Plug, Phoenix, and probably Ecto. While none of these tasks is a "rocket science", there's obviously quite a lot of ground to cover. Taking so many new things at once can overwhelm even the best of us.

So what can be done about it?

One possible approach is a full "bottom-up", where you focus first on Elixir, learn its building blocks and familiarize yourself with functional programming. Then you can move to vanilla processes, then to OTP behaviours (most notably `GenServer` and `Supervisor`), and finally OTP applications. Once you gain some confidence there, you "only" need to understand Plug and Phoenix specifics, which should be easier if you built solid foundations. I'm not suggesting you need to fully master one phase before moving to the next one. But I do think that building some solid understanding of basic concepts will make it easier to focus on the next stage.

The benefit of this approach is that you get a steady incremental progress. Understanding concurrency is easier if you don't have to wrestle with the language. Grasping Phoenix is easier if you're already confident with Elixir, OTP, and Plug. The downside is that you'll reach the final goal at the very end. You're probably interested in Phoenix because you want to build scalable, distributed, real-time web servers, but you'll spend a lot of time transforming lists with plain recursion, or passing messages between processes, before you're even able to handle a basic request. It takes some commitment to endure this first period.

If you prefer to see some tangible results immediately, you could consider a "two-pass bottom-up" approach. In this version, you could first go through excellent official getting started guides on Elixir and Phoenix sites. These should get you up to speed more swiftly than reading a few hundred pages book(s), though you won't get as much depth. On the plus side, you'll be able to experiment and prototype much earlier in the learning process. Then you can start refining your knowledge in the second pass, perhaps by reading some books, watching videos, or reading the official docs.

There are of course many other strategies you can take, so it's up to you to choose what works best for you. Whichever way you choose, don't be overwhelmed by the amount of material. Try to somehow split the learning path into smaller steps, and take new topics gradually. It's hard if not impossible to learn everything at once. It's a process that takes some time, but in my opinion, the effort is definitely worth the gain. I'm a very happy customer of Erlang/OTP/Elixir/Phoenix, and I don't think any other stack can give me the same benefits.
