One cool thing about BEAM languages is that we can implement periodic jobs without using external tools, such as cron. The implementation of the job can reside in the same project as the rest of the system, and run in the same OS process as the other activities in the system, which can help simplify development, testing, and operations.

There are various helper abstractions for running periodic jobs in BEAM, such as the built-in [:timer](https://erlang.org/doc/man/timer.html) module from Erlang stdlib, and 3rd party libraries such as [erlcron](https://github.com/erlware/erlcron), [quantum](https://hexdocs.pm/quantum/readme.html), or [Oban](https://hexdocs.pm/oban/Oban.html#module-periodic-cron-jobs).

In this article I'll present my own small abstraction called [Periodic](https://hexdocs.pm/parent/Periodic.html#content) which is a part of the [Parent](https://github.com/sasa1977/parent) library. I wrote Periodic almost two years ago, mostly because I wasn't particularly satisfied with the available options. Compared to most other periodic schedulers, Periodic makes some different choices:

- Scheduling is distributed. Each job uses its own dedicated scheduler process.
- Cron expressions are not supported.
- There is no out-of-the box support for fixed schedules.

These choices may seem controversial, but there are reasons for making them. Periodic is built to be easy to use in simple scenarios, flexible enough to power various involved cases, and simple to grasp and reason about. To achieve these properties, Periodic is deliberately designed as a small and focused abstraction. Concerns such as declarative interfaces, back-pressure and load regulation, fixed scheduling, improved execution guarantees via persistence, are left to the client code. This means that as clients of Periodic, we sometimes have to invest some more work, but what we get in return is a simple and a flexible abstraction.


## Simple usage

A periodic job can be started as follows:

```elixir
Periodic.start_link(
  run: fn -> IO.puts("Hello, World!") end,
  every: :timer.seconds(5)
)

# after 5 seconds
Hello, World

# after 10 seconds
Hello, World

# ...
```

Unlike most other periodic libraries out there, Periodic doesn't use the cron syntax. Even after many years of working with it, I still find that syntax cryptic, unintuitive, and limited. In contrast, I believe that `Periodic.start_link(run: something, every: x)` is clearer at expressing the intention.

Periodic accepts a couple of options which allow you to control its behaviour, such as dealing with overlapping jobs, interpreting delays, or terminating jobs which run too long. These options make Periodic more convenient than the built-in `:timer` functionality, with a comparable ease of use. I'm not going to discuss those options in this post, but you can take a look at [docs](https://hexdocs.pm/parent/Periodic.html#module-options) for more details.

The interface of Periodic is small. The bulk of functionality is provided in the single module which exposes two functions: `start_link` for starting the process dynamically, and `child_spec` for building supervisor specs. Two additional modules are provided - one to assist with logging, and another to help with deterministic testing.

Controversially enough, Periodic doesn't offer any special support for fixed schedules (e.g. run every Wednesday at 5pm). This might seem like a big deficiency, while it's in fact a deliberate design choice. I personally regard fixed scheduling as a nuanced challenge for which there is no one-size-fits-all solution, so it's best to make the trade-offs explicit and leave the choices to the client. Of course it's perfectly possible to power fixed scheduled jobs with Periodic, and I'll present some approaches later on in this article.


## Flexibility

Since it is based on plain functions invoked at runtime, Periodic is as flexible as it gets. You don't need to use app or OS envs, but you may use them if they suit your purposes. You don't need to define a dedicated module (although [it is advised for typical cases](https://hexdocs.pm/parent/Periodic.html#module-quick-start)), `use` some library module to inject the boilerplate, or pass anything at compile-time. In fact, Periodic is very runtime friendly, supporting various elaborate scenarios, such as on-demand starting/stopping of scheduled jobs.

Another dimension of Periodic's flexibility is its [process model](https://hexdocs.pm/parent/Periodic.html#module-process-structure). In Periodic, each job is powered by its own scheduler process. This is one of the core ideas behind Periodic which sets it apart from most other BEAM periodic schedulers I've seen.

As a result of this approach, different jobs are separate children in the supervision tree, and so, stopping an individual job is no different from stopping any other kind process. If you know how to do that with OTP, then you know everything you need to know. If you don't, you'll need to learn these techniques, but that knowledge will be applicable in the wide range of scenarios outside of Periodic.

Using supervision tree to separate runtime concerns gives us a fine grained control over job termination. Consider the following tree:

```text
       MySystem
      /        \
    Db     CacheCleanup
   /  \
Repo  DbCleanup
```

In this system we run two periodic jobs (`DbCleanup` and `CacheCleanup`). If we want to stop the database part of the system, we can do that by stopping the `Db` supervisor, taking all db-related activities down, while keeping the cache cleanup alive.

Since schedulers are a part of the supervision tree, and a scheduler acts as a supervisor (courtesy of being powered by [Parent.GenServer](https://hexdocs.pm/parent/Parent.GenServer.html)), various generic code that manipulates the process hierarchy will work with Periodic too. For example, if the job process is trapping exits, [System.stop](https://hexdocs.pm/elixir/System.html#stop/1) will wait for the job to finish, according to the job childspec (5 seconds by default).

Of course, this process design comes with some trade-offs. Compared to singleton scheduler strategies, Periodic will use twice the amount of processes. This shouldn't be problematic if the number of jobs is "reasonable", but it might hurt you if you want to run millions of jobs. However, in such case I don't think that any generic periodic library will fit the challenge perfectly, and it's more likely you'll need to roll your own special implementation, perhaps using `Parent.GenServer` to help out with some mechanical concerns.

Speaking of Parent, it's worth noting that this is the abstraction that handles supervisor aspect of the scheduler process, allowing the implementation of Periodic to remain focused and relatively small. The Periodic module currently has 410 LOC, 260 of which are user documentation. The code of Periodic is all about periodic execution concerns, such as ticking with [Process.send_after](https://hexdocs.pm/elixir/Process.html#send_after/4), starting the execution, interpreting and handling user options, and emitting telemetry events. Such division of responsibilities makes both abstractions fairly easy to grasp and reason about, while enabling `Parent.GenServer` to be used in various other situations (see [the Example section in the rationale document](https://hexdocs.pm/parent/rationale.html#examples) for details).


## Fixed scheduling

Periodic doesn't offer special support for fixed schedules (e.g. run once a day at midnight). However, such behaviour can be easily implemented on top of the existing functionality. Here's a naive take:

```elixir
Periodic.start_link(
  every: :timer.minutes(1),
  run: fn ->
    with %Time{hour: 0, minute: 0} <- Time.utc_now(),
      do: run_job()
  end
)
```

Every minute we check if the time has come to run the job. In this particular example, we'll run it every day at 00:00AM.

Careful readers will spot some possible issues in this implementation. If the system (or the scheduler process) is down at the scheduled time, the job won't be executed. Furthermore, it's worth mentioning that Periodic doesn't guarantee 100% interval precision. Though not very likely, it can (and occasionally will!) happen that in some interval a job is executed twice, while in another interval it's not executed at all. Such situations will cause our daily job to be either skipped, or executed twice in the same minute. It's worth noting that similar issues can be (and often are) present in other periodic scheduling systems, but at least in Periodic they are more explicit and clear, since they are present in our code, not in the internals of the abstraction.

If you don't care about occasional missed or extra beat, the basic take presented above will serve you just fine. In fact, if I wanted to do some daily nice-to-have cleanup, this is the version I'd start with. Perhaps the code is not as short as `0 0 * * *`, but on the upside it's more explicit about its intention and possible consequences.

## Abstracting

Our fixed scheduling code, while fairly short, might become a bit noisy and tedious if you want to run multiple fixed scheduled jobs. However, since Periodic interface is based on plain functions and arguments, nothing prevents you from generalizing the approach, for example as follows:

```elixir
defmodule NaiveDaily do
  def start_link(hour, minute, run_job) do
    Periodic.start_link(
      every: :timer.minutes(1),
      run: fn ->
        with %Time{hour: ^hour, minute: ^minute} <- Time.utc_now(),
          do: run_job.()
      end
    )
  end
end
```

And now, in your project you can do:

```elixir
NaiveDaily.start_link(0, 0, &do_something/0)
NaiveDaily.start_link(8, 0, &do_something_else/0)
```

Taking this idea further, implementing a generic translator of cron syntax to Periodic should be possible and straightforward. In theory, Parent, the host library of Periodic, could ship with such abstractions, and one day some such helpers might be added to the library. For the time being though, I'm content with keeping the library small and focused, and I'll consider expanding it after gathering some data from the usage in the wild.

## Improving execution guarantees

Our basic naive implementation of the fixed scheduler gives us "maybe once" guarantees - a job will usually be executed once a day, occasionally it won't be executed at all, while in some special circumstances it might be executed more than once in the same minute.

If we want to improve the guarantees, we need to expand the code. Luckily, since our approach is powered by a Turing-complete language, we can tweak the implementation to our needs. The general idea is to execute `if should_run?(), do: run()` every minute, tweaking the decision logic in `should_run?/0` to obtain the desired behaviour.

It's easy to see how this approach is flexible. For example, implementing more elaborate schedules such as "run every 10 minutes during working hours, but once per hour otherwise" is possible with a properly crafted conditional.

When it comes to improving the execution guarantees, we need to extend the code a bit more. Here's a basic sketch:

```elixir
Periodic.start_link(
  every: :timer.minutes(1),
  run: fn ->
    unless job_executed_today?() do
      run_job()
      mark_job_as_executed_today()
    end
  end
)
```

As the name suggests `job_executed_today?/0` has to somehow figure out if we already ran the job. A simple version can be powered by a global in-memory data (e.g. using ETS), which should improve the chance of the job getting executed at least once a day, but it would also increase the chance of unwanted repeated executions.

If we opt to base the logic on some persistence storage (say a database), we can reduce the chance of repeated executions. Note however that an occasional duplicate might still happen if the system is shut down right after the job is executed, but before it's marked as executed. In this case, we'll end up executing the job again after the restart. This issue can only be eliminated in some special circumstances, such as:

- The job manipulates the same database where we mark job as executed. In this case we can transactionally run the job and mark it as executed.
- The target of the job supports idempotence, allowing us to safely rerun the job without producing duplicate side-effects.

Here's a bit more involved scenario, which I actually had to solve in real-life. Suppose that we want to run a periodic cleanup during the night, but only if no other activity in the system is taking place. Moreover, while the job is running, all pending activities should wait. Here's a basic sketch:

```elixir
Periodic.start_link(
  every: :timer.minutes(1),
  on_overlap: :ignore,
  run: fn ->
    if Time.utc_now().hour in 0..4 and not job_executed_today?() do
      with_exclusive_lock(fn ->
        run_job()
        mark_job_as_executed_today()
      end)
    end
  end
)
```

The implementation relies on some exclusive lock mechanism. In a simple version we can use [:global.trans](https://erlang.org/doc/man/global.html#trans-4) to implement a basic version of RW locking that would permit regular activities to grab the lock simultaneously (readers), while the job would be treated as a writer which grabs the lock exclusively to anyone else. Also note the usage of the `on_overlap: :ignore` option, which makes sure we don't run multiple instances of the job simultaneously.

In a real-life scenario I used this approach, combined with ad-hoc persistence to a local file with [:erlang.term_to_binary](http://erlang.org/doc/man/erlang.html#term_to_binary-1) and [its counterpart](http://erlang.org/doc/man/erlang.html#binary_to_term-1). The project was completely standalone, powered at runtime by a single BEAM instance, and nothing else running on the side.

This is a nice example of how we profit from the fact that the periodic execution is running together with the rest of the system. There's a natural strong dependency between the job and other system activities, and we can model this dependency without needing to run external moving pieces, such as e.g. Redis. Our implementation is a straightforward representation of the problem, and it can even be easily tested!

The locking mechanism could also be used to ensure that the job is executed only on a single machine in the cluster:

```elixir
Periodic.start_link(
  every: :timer.minutes(1),
  on_overlap: :ignore,
  run: fn ->
    # eager check to avoid excessive locking
    if should_run?() do
      with_exclusive_lock(fn ->
        # The repeated check makes sure the job hasn't been executed
        # on some other machine while we were waiting for the lock.
        if should_run?() do
          run_job()
          mark_job_as_executed()
        end
      end)
    end
  end
)
```

In this version, `with_exclusive_lock` would be based on some shared locking mechanism, for example using database locks, or some distributed locking mechanism like [:global](https://erlang.org/doc/man/global.html).


## Final thoughts

As an author, I'm admittedly very partial to Periodic. After all, I made it pretty much the way I wanted it. That said, I believe that it has some nice properties.

With a small and intention-revealing interface, simple process structure, and OTP compliance, I believe that Periodic is a compelling choice for running periodical jobs directly in BEAM. Assuming nothing about the preferences of different clients, sticking to plain functions, and using a simple process structure make Periodic very flexible, and allow clients to use it however they want to. Building specialized abstractions on top of Periodic, such as the sketched `NaiveDaily` is possible and straightforward.

The lack of dedicated support for fixed-time scheduling admittedly requires a bit more coding on the client part, but it also motivates the clients to consider the consequences and trade-offs. A naive solution, which should be roughly on par with what other similar libs are providing, is short and straightforward to implement. More demanding scenarios will require comparative effort in the code, but that's something that can't be avoided. On the plus side, all the approaches will share a similar pattern of `if should_run?(), do: run()`, typically executed once a minute. Since the decision logic is implemented Elixir, the client code has full freedom in the decision making process.

In summary, I hope that this article will motivate you to give Periodic a try. If you spot some problems or have some feature proposals, feel free to open up an issue on the [project repo](https://github.com/sasa1977/parent).
