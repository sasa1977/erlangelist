What is app env, and what should we use it for? The Elixir docs [state](https://hexdocs.pm/elixir/Application.html#module-application-environment):

> OTP provides an application environment that can be used to configure the application.

In my experience, an app env of a moderately complex system will typically contain the following things:

- Things which are system configuration
- Things which aren't system configuration
- Things which, when modified at runtime, affect the system behaviour
- Things which, when modified at runtime, don't affect the system behaviour
- Things which vary across different mix environments
- Things which don't vary across different mix environments
- Things which are essentially code (e.g. MFA triplets and keys which are implicitly connected to some module)

In other words, app env tends to degenerate into a bunch of key-values arbitrarily thrown into the same place. In this article I'll try to reexamine the way we use app env, and its closely related Elixir cousin config scripts (`config.exs` and friends), and propose a different approach to configuring Elixir systems. The ideas I'll present might sound heretical, so I should warn you upfront that at the point of writing this, it's just my personal opinion, and not the community standard, nor the approach suggested by the Elixir core team.

However, if you keep an open mind, you might find that these ideas might lead to some nice benefits:

- Better organized configuration code
- Complete flexibility to fetch configuration data from arbitrary sources
- Much less bloat in config scripts and app env

There's a long road ahead of us, so let's kick off.

## Live reconfiguration

Technically speaking, app env is a mechanism which allows us to keep some application specific data in memory. This data is visible to all processes of any app, and any process can change that data. Under the hood, the app env data sits in a publicly accessible ETS table named `:ac_tab`, so it has the same semantics as ETS.

So what is it really good for? Let's see a simple example. Suppose we need to run a periodic job, and we want to support runtime reconfiguration. A simple implementation could look like this:

```elixir
defmodule PeriodicJob do
  use Task

  def start_link(_arg), do: Task.start_link(&loop/0)

  defp loop() do
    config = Application.fetch_env!(:my_system, :periodic_job)
    Process.sleep(Keyword.fetch!(config, :interval))
    IO.puts(Keyword.fetch!(config, :message))

    loop()
  end
end
```

Notice in particular how we're fetching the periodic job parameters from app env in every step of the loop. This allows us to reconfigure the behaviour at runtime. Let's try it out:

```elixir
iex> defmodule PeriodicJob do ... end

iex> Application.put_env(
        :my_system,
        :periodic_job,
        interval: :timer.seconds(1),
        message: "Hello, World!"
      )

iex> Supervisor.start_link([PeriodicJob], strategy: :one_for_one)

Hello, World!   # after 1 sec
Hello, World!   # after 2 sec
...
```

Now, let's reconfigure the system:

```elixir
iex> Application.put_env(
        :my_system,
        :periodic_job,
        interval: :timer.seconds(5),
        message: "Hi, World!"
      )

Hello, World!   # after at most 1 sec
Hi, World!      # 5 seconds later
Hi, World!      # 10 seconds later
```

So in this example, we were able to reconfigure a running system without restarting it. It's also worth noting that you can do the same thing in a system running in production, either via a remote `iex` shell or using the `:observer` tool.

An important point is that this live reconfiguration works because the code doesn't cache the app env data in a local variable. Instead, it refetches the configuration in every iteration. This is what gives us runtime configurability.

In contrast, if a piece of data is fetched from app env only once, then changing it at runtime won't affect the behaviour of the system. Let's see an example. Suppose we're writing a web server, and want to configure it via app env. A simple plug-based code could look like this:

```elixir
defmodule MySystem.Site do
  @behaviour Plug

  def child_spec(_arg) do
    Plug.Adapters.Cowboy2.child_spec(
      scheme: :http,
      plug: __MODULE__,
      options: [port: Application.fetch_env!(:my_system, :http_port)]
    )
  end

  ...
end

```

Let's say that the HTTP port is initially set to 4000. We start the system, and try to reconfigure it dynamically by changing the port to 5000:

```
iex> Application.put_env(:my_system, :http_port, 5000)
```

Unsurprisingly, this will not affect the behavior of the system. The system will still listen on port 4000. To force the change, you need to force restart the parent supervisor. Why the parent supervisor, and not the process? Because in this case the app env is fetched in `child_spec/1` which is only invoked while the parent is initializing.

So, in this plug example, the site can theoretically be dynamically reconfigured, but doing it is quite clumsy. You need a very intimate knowledge of the code to reapply the app env setting. So for all practical intents and purposes, the port app env setting is constant.

This begs the question: if an app env value is a constant which doesn't affect the runtime behaviour, why keep it in app env in the first place? It's one more layer of indirection, and so it has to be justified somehow.

Some possible reasons for doing it would be:

1. Varying configuration between different mix envs (dev, test, prod)
2. Consolidating system configuration into a single place
3. Dependency library requires it

While the third scenario can't be avoided, I believe that for the first two, app env and config scripts are far from perfect. To understand why, let's look at some config scripts issues.

## Context conflation

Suppose you need to use an external database in your system, say a PostgreSQL database, and you want to work with it via Ecto. Such scenario is common enough that even Phoenix will by default generate the Ecto repo configuration for you when you invoke `mix phx.new`:

```elixir
# dev.exs
config :my_system, MySystem.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "my_system_dev",
  hostname: "localhost",
  pool_size: 10

# test.exs
config :my_system, MySystem.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "my_system_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# prod.secret.exs
config :my_system, MySystem.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "my_system_prod",
  pool_size: 15
```

You get different database configurations in dev, test, and prod. The `prod.secret.exs` file is git-ignored so you can freely point it to the local database, without the fear of compromising production or committing production secrets.

At first glance this looks great. We have varying configuration for different mix envs, and we have a way of running a prod-compiled version locally. However, this approach is not without its issues.

One minor annoyance is that, since you can't commit `prod.secret.exs` to the repo, every developer in the team will have to populate it manually. It's not a big issue, but it is a bit clumsy. Ideally, the development setup would work out of the box.

A more important issue is the production setup. If you're running your system as an OTP release (which I strongly advise), you'll need to host the secret file at the build server, not the production server. If you want to manage a separate staging server which uses a different database, you'll need to somehow juggle with multiple secret configs on the build server, and separately compile the system for staging and production.

The approach becomes unusable if you're deploying your system on client premises, which is a case we have at Aircloak (for a brief description of our system, see [this post](https://elixirforum.com/t/aircloak-anonymized-analitycs/10930)). In this scenario, the development team doesn't know the configuration parameters, while the system admins don't have the access to the code, nor Elixir/Erlang know-how. Therefore, config scripts can't really work here.

Let's take a step back. The root cause of the mentioned problems is that by setting up different db parameters in different mix envs we're conflating compilation and runtime contexts. In my view mix env (dev/test/prod) is a compilation concern which determines variations between compiled version. So for example, in dev we might configure auto code recompiling and reloading, while in prod we'll turn that off. Likewise, in dev and test, we might disable some system services (e.g. fetching from a Twitter feed), or use fake replacements.

However, a mix env shouldn't assume anything about the execution context. I want to be able to run a prod compiled version locally, so I can do some local verification or benching for example. Likewise, once I assemble an OTP release for prod, in addition to running it on a production box, I want to run it on a staging server using a separate database.

These are not scenarios which can be easily handled with config scripts, and so it follows that config scripts are not a good fit for specifying the differences between different execution contexts.

## Config script execution time

A better way to specify these differences is to use an external configuration source, say an OS env, an externally supplied file, or a KV such as etcd.

Let's say that we decided to keep connection parameters in an OS env. The configuration code could look like this:

```elixir
# config.exs
config :my_system, MySystem.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: System.get_env("MY_SYSTEM_DB_USERNAME"),
  password: System.get_env("MY_SYSTEM_DB_PASSWORD"),
  database: System.get_env("MY_SYSTEM_DB_DATABASE"),
  hostname: System.get_env("MY_SYSTEM_DB_HOSTNAME")

# configure other variations in dev/test/prod.exs
```

And then, we can set different OS env vars on target machines, and now we can compile a prod version once, and run it on different boxes using different databases.

However, this will lead you to another problem. In the current Elixir (1.6), config scripts are evaluated during compilation, not the runtime. So if you're using OTP releases and assemble them on a separate build server (which is a practice I recommend for any real-life project), this simply won't fly today. The env parameters are retrieved during compilation, not during runtime, and so you end up with the same problem.

Admittedly, the Elixir team has plans to [move the execution of config scripts to runtime](https://elixirforum.com/t/proposal-moving-towards-discoverable-config-files/14302), which means that this issue will be solved in the future. However, if you need to fetch the data from an external source such as a json file or an etcd instance, then this change won't help you. It's essentially a chicken-and-egg problem: app env values need to be resolved before the apps are started, and so even at runtime, the config script needs to run before a dependency such as e.g. JSON decoder or an etcd client is loaded. Consequently, if you need to fetch a value using a dependency library, config scripts is not the place to do it.

The thing is that config scripts are evaluated too soon. In the worst case, they're evaluated during compilation on a build server, and in the best case they're evaluated before any dependency is started. In contrast, the services of our system, such as repo, endpoint, or any other process, are started way later, sometimes even conditionally. Consequently, config scripts often force you to fetch the config values much sooner than the moment you actually need them.

## Configuring at runtime

Given the issues outlined above, my strong opinion is that connection parameters to external services don't belong to config scripts at all. So where do we configure the connection then? Previously, this required some trickery, but luckily Ecto and Phoenix have recently added an explicit support for runtime configuration in the shape of the `init/2` callback.

So here's one way how we could configure our database connection params:

```elixir
defmodule MySystem.Repo do
  use Ecto.Repo, otp_app: :my_system

  def init(_arg, app_env_db_params), do:
    {:ok, Keyword.merge(app_env_db_params, db_config())}

  defp db_config() do
    [
      hostname: os_env!("MY_SYSTEM_DB_HOST"),
      username: os_env!("MY_SYSTEM_DB_USER"),
      password: os_env!("MY_SYSTEM_DB_PASSWORD"),
      database: os_env!("MY_SYSTEM_DB_NAME")
    ]
  end

  defp os_env!(name) do
    case System.get_env(name) do
      nil -> raise "OS ENV #{name} not set!"
      value -> value
    end
  end
end
```

With this approach, we have moved the retrieval of connection params to runtime. When the repo process is starting, Ecto will first read the app config (configured through a config script), and then invoke `init/2` which can fill in the blanks. The big gain here is that `init/2` is running at runtime, while your application is starting and when your dependencies have already been started. Therefore, you can now freely invoke `System.get_env`, or `Jason.decode!`, or `EtcdClient.get`, or anything else that suits your purposes.

## Consolidating service configuration

One issue with the code above is that it's now more difficult to use a different database in the test environment. This could be worked around with a `System.put_env` call placed in `test_helper.exs`. However, that approach won't fly if the source of truth is a file or an etcd instance. What we really want is the ability to bypass the OS env check in test environment, and enforce the database name in a different way.

Config script give you a very convenient solution to this problem. You could provide the database name only in `test.exs`:

```elixir
# test.exs

config :my_system, MySystem.Repo, database: "my_system_test"
```

And then adapt the configuration code:

```elixir
defmodule MySystem.Repo do
  use Ecto.Repo, otp_app: :my_system

  def init(_arg, app_env_db_params), do:
    {:ok, Keyword.merge(app_env_db_params, db_config(app_env_db_params))}

  defp db_config(app_env_db_params) do
    [
      hostname: os_env!("MY_SYSTEM_DB_HOST"),
      username: os_env!("MY_SYSTEM_DB_USER"),
      password: os_env!("MY_SYSTEM_DB_PASSWORD"),
      database:
        Keyword.get_lazy(
          app_env_db_params,
          :database,
          fn -> os_env!("MY_SYSTEM_DB_NAME") end
        )
    ]
  end

  ...
end
```

While this will fix the problem, the solution leaves a lot to be desired. At this point, the database is configured in different config scripts and in the repo module. I personally find this quite confusing. To grasp the database configuration in a particular mix env, you need to consider at least three different files: `config.exs`, `"#{Mix.env}.exs"`, and the repo module source file. To make matters worse, the config files will be bloated with other unrelated configurations (e.g. endpoint settings), and the database configuration could even be dispersed throughout the config in the shape of:

```elixir
# config.exs

config :my_system, MySystem.Repo, ...

# tens or hundreds of lines later

config :my_system, MySystem.Repo, ...

...
```

Let's consider why do we even use config script in the first place. We already pulled database parameters to `init/2`, but why are other repo parameters still in config scripts? The reason is because it's very convenient to encode variations between mix envs through config scripts. You just put stuff in the desired `"#{Mix.env}.exs"` and you're good to go. However, you never get something for nothing, so you pay for this writing convenience by sacrificing the reading experience. Understanding the database configuration becomes much harder.

A better reading experience would be if the entire database configuration was consolidated in one place. Since we need to determine some parameters at runtime, `init/2` has to be that place. But how can we encode variations between different mix envs? Luckilly, this is fairly simple with a light touch of Elixir metaprogramming:

```elixir
defp db_config() do
  [
    # ...
    database: db_name()
  ]
end

# ...

if Mix.env() == :test do
  defp db_name(), do: "my_system_test"
else
  defp db_name(), do: os_env!("MY_SYSTEM_DB_NAME")
end
```

This code is somewhat more elaborate, but it's now consolidated, and more explicit. This code clearly states that in the test env the database name is forced to a particular value, i.e. it's not configurable. In contrast, the previous version is more vague about its constraints, and so leaves room for mistakes. If you're renaming the repo module but forget to update the config script, you might end up running tests on your dev db and completely mess up your data.

It's worth noting that you should only ever invoke `Mix.env` during compilation, so either at the module level (i.e. outside of named functions), or inside an `unquote` expression. Mix is not available at runtime, and even if it were, `Mix.env` can't possibly give you a meaningful result. Remember, mix env is a compilation context, and so you can't get it at runtime.

If you dislike the if/else noise of the last attempt, you can introduce a simple helper macro:

```elixir
# ...

defmacrop env_specific(config) do
  quote do
    unquote(
      Keyword.get_lazy(
        config,
        Mix.env(),
        fn -> Keyword.fetch!(config, :else) end
      )
    )
  end
end

# ...

defp db_config() do
  [
    # ...
    database: env_specific(test: "my_system_test", else: os_env!(...))
  ]
end
```

Notice that this doesn't change the semantics of the compiled code. Since `env_specific` is a macro, invoking it will make a compile-time decision to inject one code or another (a constant value or a function call). So for example, in test environment, the code `os_env!(...)` won't be executed, nor even make it to the compiled version. Consequently, you can freely invoke anything you want here, such as json decoding, or fetching from etcd for example, and it will be executed at runtime, only in the desired mix env.

As an added bonus, the `env_specific` macro requires that the value is specified for the current mix env, or that there's an `:else` setting. The macro will complain at compile time if the value is not provided.

To summarize, with a touch of metaprogramming we achieved the feature parity with config scripts, moved the retrieval of parameters to runtime, consolidated the repo configuration, and expressed variations between mix envs more clearly and with stronger guarantees. Not too shabby :-)

## Consolidating system configuration

One frequent argument for app env and config scripts is that they allow us to consolidate all the parameters of the system in a single place. So, supposedly, config scripts become a go-to place which we can refer to when we want to see how some aspect of the system is configured.

However, as soon as you want to configure external services, such as a database, you're left with two choices:

1. Shoehorn configuration into config scripts
2. Move configuration to runtime

In the first case, you'll need to resort to all sorts of improvisations to make it work. As soon as you need to support multiple execution contexts, you're in for a ride, and it won't be fun :-). You might consider abandoning OTP releases completely, and just run `iex -S mix` in prod, which is IMO a very bad idea. Take my advice, and don't go there :-)

This leaves you with the second option: some system parameters will be retrieved at runtime. And at this point, config script ceases to be the single place where system parameters are defined.

That's not a bad thing though. To be honest, I think that config script is a poor place to consolidate configuration anyway. First of all, config scripts tend to be quite noisy, and contain all sorts of data, including the things which are not a part of system configuration at all.

Consider the following configuration generated by Phoenix:

```elixir
config :my_system, MySystem.Repo, adapter: Ecto.Adapters.Postgres, ...
```

Is database adapter really a configurable thing? Can you just change this to, say, MySql and everything will magically work? In my opinion, unless you've explicitly worked to support this scenario it will fail spectacularly. Therefore, the adapter is not a parameter to your system, and hence it doesn't belong here.

As an aside, at Aircloak, due to the nature of our system, the database adapter is a configurable parameter. However, what's configured is not an Ecto adapter, but rather a particular setting specific to our system. That setting will affect how the system works with the database, but the internal variations are way more complex. Supporting different databases required a lot of work, beyond just passing one Ecto adapter or the other. We needed to support this scenario, and so we invested the effort to make it happen. If you don't have such needs, then you don't need to invest that effort, and database adapter is not your system's configuration parameter. In theory you can change it, in practice you can't :-)

Here's another example of a config bloat:

```elixir
config :my_system, MySystemWeb.Endpoint,
  # ...
  render_errors: [view: MySystemWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: MySystem.PubSub, adapter: Phoenix.PubSub.PG2],
  # ...
```

These things are not configuration parameters. While in theory we could construct a scenario where this needs to be configurable, in most cases it's just YAGNI. These are the parameters of the library, not of the system, and hence they only add bloat to config scripts and app env.

Another problem is that config scripts tend to be populated in an arbitrary way. My personal sentiment is that their content becomes a function of arbitrary decisions made by different people at different points in time. At best, developers make a sensible effort to keep things which "feels" like system configuration in config scripts. More often, the content of config scripts is determined the by demands of libraries, the defaults established by the code generators, and convenient ability to vary the values across different mix envs.

In summary, the place for the supposed consolidated system configuration will contain:

- Some, but not all things which are system parameters
- Some things which are not system parameters

Let's take a step back here and consider why do we even want a consolidated system configuration.

One reason could be to make it easier for developers to find the parameters of the system. So if we need to determine database connection parameters, the HTTP port, or a logging level, we can just open up the config script, and find it there.

Personally, I have a hard time accepting this argument. First of all, the configuration IMO naturally belongs to the place which uses it. So if I'm interested in db connection parameters, I'd first look at the repo module. And if I want to know about the endpoint parameters, then I'd look at the endpoint module.

Such approach also makes it easier to grasp the configuration. When I read config scripts, I'm spammed with a bunch of unrelated data which I neither care about at the moment, nor can hold together in my head. In contrast, when I read a consolidated repo config in isolation, I can more easily understand it.

A more important reason for system config consolidation is to assist administration by external administrators. These people might not have the access to the source code, or maybe they're not fluent in Elixir, so they can't consult the code to discover system parameters. However, for the reasons I've stated above, I feel that config scripts won't suffice for this task. As mentioned, database connection parameters will likely not be a part of the config script, and so the complete consolidation is already lost. In addition, if external admins are not fluent in Elixir, they could have problems understanding elixir scripts, especially if they are more dynamic.

If you plan on assisting administration, consider using well understood external configuration sources, such as ini, env, or json files, or KVs such as etcd. If you do that, then app env will not be needed, and config scripts will not suffice anyway, so you'll likely end up with some variation of the configuration style proposed above, which is performed at runtime.

As a real-life example, the system we're building at Aircloak is running on client premises, and has to be configured by the client's administrators. We don't have the access to their secrets, and they don't have the access to our source code. To facilitate administration, we fetch system parameters from a json file which has to be provided by the administrators. We've explicitly and carefully cherry picked the parameters which belong to system configuration. Everything else is an implementation detail, and so it doesn't cause bloat in the config. As a consequence, we know exactly which pieces of data can be provided in the configuration, and so we can validate the config file against a schema and fail fast if some key name is misspelled, or some data is not of the right type.

## Configuring a Phoenix endpoint

Let's take a look at a more involved example. This blog is powered by Phoenix, and the endpoint is completely configured at runtime. Therefore, the only endpoint-related config piece is the following:

```elixir
config :erlangelist, ErlangelistWeb.Endpoint, []
```

The reason why we need an empty config is because Phoenix requires it.

All of the endpoint parameters are provided in `init/2`:

```elixir
defmodule ErlangelistWeb.Endpoint do
  # ...

  def init(_key, phoenix_defaults),
    do: {:ok, ErlangelistWeb.EndpointConfig.config(phoenix_defaults)}
end
```

Since there are a lot of parameters and significant variations between different mix envs, I've decided to move the code into another module, to separate plug chaining from configuration assembly. The function `ErlangelistWeb.EndpointConfig.config/1` looks like this:

```elixir
def config(phoenix_defaults) do
  phoenix_defaults
  |> DeepMerge.deep_merge(common_config())
  |> DeepMerge.deep_merge(env_specific_config())
  |> configure_https()
end
```

Starting with the default values provided by Phoenix, we'll apply some common settings, and then env-specific settings, and finally do some https specific tuning (which is needed due to auto certification with Let's Encrypt).

Note that I'm doing a deep merge here, since env specific settings might partially overlap with the common ones. Since, AFAIK, deep merging is not available in Elixir, I've resorted to the [DeepMerge](https://github.com/PragTob/deep_merge) library.

The common config determines the parameters which don't vary between mix envs:

```elixir
defp common_config() do
  [
    http: [compress: true, port: 20080],
    render_errors: [view: ErlangelistWeb.ErrorView, accepts: ~w(html json)],
    pubsub: [name: Erlangelist.PubSub, adapter: Phoenix.PubSub.PG2]
  ]
end
```

Notice how the http port is hardcoded. The reason is because it's the same in all mix envs, and on all host machines. It always has this particular value, and so it's a constant, not a config parameter. In production, the request arrive on port 80. However, this is configured outside of Elixir, by using iptables to forward the port 80 to the port 20080. Doing so allows me to run the Elixir system as a non-privileged user.

Since the variations between different envs are significant, I didn't use the `env_specific` macro trick. Instead, I opted for the plain `Mix.env` based switch:

```elixir
case Mix.env() do
  :dev -> defp env_specific_config(), do: # dev parameters
  :test -> defp env_specific_config(), do: # test parameters
  :prod -> defp env_specific_config(), do: # prod parameters
end
```

The complete version can be seen [here](https://github.com/sasa1977/erlangelist/blob/70d664e5a7d71638aedb1bc0f12ece15995c49e3/site/lib/erlangelist_web/endpoint_config.ex#L24-L61).

This consolidation allows me to find the complete endpoint configuration in a single place - something which is not the case for config scripts. So now I can clearly see the differences between dev, test, and prod, without needing to simultaneously look at three different files, and a bunch of unrelated noise. It's worth repeating that this code has the feature parity with config scripts. In particular, the dev- and the test-specific parameters won't make it into the prod-compiled version.

## Supporting runtime configurability

For fun and experiment, I also added a bit of runtime configurability which allows me to change some behaviour of the system without restarting anything.

When this site is running, I keep some aggregated usage stats, so I can see the read count per each article. This is implemented in a quick & dirty way using `:erlang.term_to_binary` and storing data into a file. I use a separate file for each day, and the system periodically deletes older files.

The relevant code sits in the `Erlangelist.Core.UsageStats` module, which is also responsible for its own configuration. The configuration specifies how often is the in-memory data flushed to disk, how often is the cleanup code invoked, and how many files are preserved during the cleanup. Here are the relevant pieces of the configuration code:

```elixir
defmodule Erlangelist.Core.UsageStats do

  def start_link(_arg) do
    init_config()
    ...
  end

  defp init_config(),
    do: Application.put_env(:erlangelist, __MODULE__, config())

  defp config() do
    [
      flush_interval:
        env_specific(
          prod: :timer.minutes(1),
          else: :timer.seconds(1)
        ),
      cleanup_interval:
        env_specific(
          prod: :timer.hours(1),
          else: :timer.minutes(1)
        ),
      retention: 7
    ]
  end

  ...
end
```

Just like with endpoint and repo, the configuration is encapsulated in the relevant module. However, since I want to support dynamic reconfiguration, I'm explicitly storing this config into the app env before I start the process. Finally, I only ever access these parameters by directly invoking `Application.fetch_env!` (see [here](https://github.com/sasa1977/erlangelist/blob/70d664e5a7d71638aedb1bc0f12ece15995c49e3/site/lib/erlangelist/usage_stats.ex#L37) and [here](https://github.com/sasa1977/erlangelist/blob/70d664e5a7d71638aedb1bc0f12ece15995c49e3/site/lib/erlangelist/usage_stats.ex#L49-L50)), without caching the values in variables. Therefore, changing any of these app env settings at runtime will affect the future behaviour of the system.

As a result of this style of configuration, the config scripts become very lightweight:

```elixir
# config.exs
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:user_id]

config :erlangelist, ErlangelistWeb.Endpoint, []


# dev.exs
config :logger, level: :debug, console: [format: "[$level] $message\n"]
config :phoenix, :stacktrace_depth, 20


# test.exs
config :logger, level: :warn
```

And the full app env of the `:erlangelist` app is very small, consisting mostly of parameters which can affect the runtime behaviour of the system:

```elixir
iex> Application.get_all_env(:erlangelist)
[
  {Erlangelist.Core.UsageStats,
   [flush_interval: 1000, cleanup_interval: 60000, retention: 7]},
  {ErlangelistWeb.Endpoint, []},
  {:included_applications, []}
]
```

## Libraries and app env

Sometimes a dependency will require some app env settings to be provided, and so you'll need to use config scripts. For example, the logging level of the Logger application is best configured in a config script. Logger actually [supports runtime configuration](https://hexdocs.pm/logger/Logger.html#module-runtime-configuration), so you could set the logger level in your app start callback. However, at the point your app is starting, your dependencies are already started, so the setting might be applied too late. Thus such configuration is best done through a config script.

There are also many libraries, both Erlang and Elixir ones, which needlessly require the parameters to be provided via app config. If you're a library author, be very cautious about opting for such interface. In most cases, a plain functional interface, where you take all the options as function parameters, will suffice. Alternatively (or as well), you could support a callback similarly to Ecto and Phoenix, where you invoke the `init` callback function, allowing the clients to provide the configuration at runtime.

There are some cases where requiring app config is the best choice (a good example is the aforementioned Logger), but such scenarios are few and far between. More often than not, a plain functional interface will be a superior option. Besides keeping things simple, and giving maximum flexibility to your users, you'll also be able to better document and enforce the parameter types via typespecs.

I'd also like to caution against keeping code references in config scripts. MFAs or atoms which are implicitly tied to modules in the compiled code are an accident waiting to happen. If you rename the module, but forget to update the config, things will break. If you're lucky, they will break abruptly in tests. If not, they will silently not work in prod, and you might face all sorts of strange issues which will be hard to troubleshoot.

If you're a library author, try not to enforce your users to set a `Foo.Bar` app env key and define the module of the same name. This is rarely a good approach, if ever. There will be occasional cases where e.g. a module needs to be provided via app config. A good example is plugging custom log backends into the logger. But, again, such situations are not common, so think hard before making that choice. In most cases taking functions or callback modules via parameters will be a better option.

## Final thoughts

In my impression, Elixir projects tend to overuse config scripts and app env. The reasons are likely historic. As far as I remember, even pure Erlang libraries frequently required, or at least promoted, app envs with no particular technical reasons.

I feel that this overuse is further amplified by Elixir config scripts, which are admittedly very convenient. They simplify the writing process, but they also make it easy to add bloat to app env. Consequently, we end up with config scripts which don't describe the complete system configuration, but frequently contain things which are not configuration at all. Since they are executed at compile time, the config scripts can cause a lot of confusion, and will not work if you need to fetch parameters from other sources, such as OS env. Even if the Elixir team manages to move config execution to runtime, they will still likely be limited in what they can offer. Fetching from sources such as etcd or external files (json, ini) will require different solutions.

In my opinion, a better approach is to drive configuration retrieval at runtime, from the place which actually needs it. Fetch the site configuration in the endpoint module, and the repo configuration in the repo module. That will separate different configuration concerns, but will consolidate the parameters which naturally belong together. Most importantly, it will shift the configuration retrieval to runtime, giving you a much higher degree of flexibility.

Keep in mind that app env is just another data storage, and not a central place for all config parameters. That storage has its pros and cons, and so use it accordingly. If you read the data from app env only once during startup, then why do you need app env in the first place? If you're copying the data from OS env to app env, why not just skip app env and always read it from an OS env instead? If you need to cache some parameters to avoid frequent roundtrips to an external storage, consider using a dedicated ets table or a caching library such as Cachex.

Since app env values can be changed at runtime, limit the app env usage to the pieces of data which can be used to change the system behaviour. Even in those cases, you'll likely be better of without config scripts. Define the configuration data in the place where it is used, not in a common k-v store.

When your dependency requires an app env during its startup, your best option is to provide it via a config script. If you use config scripts only in such cases, they will be much smaller and easier to grasp. If you feel that the library needlessly requires app env setting, contact the maintainers and see if it can be improved.

Be careful about using config scripts to vary the behaviour between different mix envs. You can achieve the same effect with bit of Elixir metaprogramming. Doing so will help you consolidate your configuration, and keep the things which are not system parameters outside of app env and config script. Keep in mind that `Mix` functions shouldn't be invoked at runtime, and that `Mix.env` has no meaning at runtime.

Make the distinction between compile time and execution contexts. If you compile with `MIX_ENV=prod`, you've compiled a production version, not the version that can only run on a production box. A prod compiled code should be easily invokable on a dev box, and on a staging machine. Consequently, variations between execution contexts are not variations between compilation contexts, and thus don't belong to configuration scripts, nor any other mechanism relying on `Mix.env`.

Finally, if you do want to consolidate your system parameters to assist external administrators, consider using well understood formats, such as env, ini, or json files, or storages such as etcd. Cherry pick the parameters which are relevant, and leave out the ones which are implementation details. Doing so will keep your configuration in check, and make it possible to validate it during startup.

As a final parting gift, here is some recommended further reading:

- [Avoid application configuration section, library guidelines of the official Elixir docs](https://hexdocs.pm/elixir/master/library-guidelines.html#avoid-application-configuration)
- [Configuring Elixir libraries, Michał Muskała](https://michal.muskala.eu/2017/07/30/configuring-elixir-libraries.html)
- [Best practices for deploying Elixir apps, Jake Morrison](https://www.cogini.com/blog/best-practices-for-deploying-elixir-apps/)

Happy configuring! :-)
