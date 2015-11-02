In this post I'll talk about less typical patterns of parallelization with tasks. Arguably, the most common case for tasks is to start some jobs concurrently with `Task.async` and then collect the results with `Task.await`. By doing this we might run separate jobs in parallel, and thus perform the total work more efficiently. This can be done very elegantly with async/await without the much overhead in the code.

However, async/await have some properties which may not be suitable in some cases, so you might need a different approach. That is the topic of this post, but first, let's quickly recap the basic async/await pattern.

## Parallelizing with async/await
Async/await makes sense when we need to perform multiple independent computations and aggregate their results into the total output. If computations take some time, we might benefit by running them concurrently, possibly reducing the total execution time from `sum(computation_times)` to `max(computation_times)`.

The computation can be any activity such as database query, a call to a 3rd party service, or some CPU bound calculation. In this post, I'll just use a contrived stub:

```elixir
defmodule Computation do
  def run(x) when x > 0 do
    :timer.sleep(x)  # simulates a long-running operation
    x
  end
end
```
This "computation" takes a positive integer `x`, sleeps for `x` milliseconds, and returns the number back. It's just a simulation of a possibly long running operation.

Now, let's say that we need to aggregate the results of multiple computations. Again, I'll introduce a simple stub:

```elixir
defmodule Aggregator do
  def new, do: 0
  def value(aggregator), do: aggregator

  def add_result(aggregator, result) do
    :timer.sleep(50)
    aggregator + result
  end
end
```
This is just a simple wrapper which sums input numbers. In real life, this might be a more involved aggregator that somehow combines results of multiple queries into a single "thing".

Assuming that different computations are independent, there is potential to run them concurrently, and this is where tasks come in handy. For example, let's say we need to run this computation for ten different numbers:

```elixir
defmodule AsyncAwait do
  def run do
    :random.seed(:os.timestamp)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) end)
    |> Enum.map(&Task.async(fn -> Computation.run(&1) end))
    |> Enum.map(&Task.await/1)
    |> Enum.reduce(Aggregator.new, &Aggregator.add_result(&2, &1))
    |> Aggregator.value
  end
end
```
This is a fairly simple technique. First, we generate some random input and start the task to handle each element. Then, we await on results of each task and reduce responses into the final value. This allow us to improve the running time, since computations might run in parallel. The total time should be the time of the longest running computation plus the fixed penalty of 500 ms (10 * 50 ms) to include each result into the total output. In this example it shouldn't take longer than 1500 ms to get the final result.

## Properties of async/await
Async/await is very elegant and brings some nice benefits, but it also has some limitations.

The first problem is that we await on results in the order we started the tasks. In some cases, this might not be optimal. For example, imagine that the first task takes 500 ms, while all others take 1 ms. This means that we'll process the results of short-running tasks only after we handle the slow task. The total execution time in this example will be about 1 second. From the performance point of view, it would be better if we would take results as they arrive. This would allow us to aggregate most of the results while the slowest task is still running, reducing the execution time to 550 ms.

Another issue is that it's not easy to enforce a global timeout. You can't easily say, "I want to give up if all the results don't arrive in 500 ms". You can provide a timeout to `Task.await` (it's five seconds by default), but this applies only to a single await operation. Hence, a five seconds timeout actually means we might end up waiting 50 seconds for ten tasks to time out.

Finally, you should be aware that async/await pattern takes the all-or-nothing approach. If any task or the master process crashes, all involved processes will be taken down (unless they're trapping exits). This happens because `Task.async` links the caller and the spawned task process.

In most situations, these issues won't really matter, and async/await combo will be perfectly fine. However, sometimes you might want to change the default behaviour.

## Eliminating await
Let's start by making the "master" process handle results in the order of arrival. This is fairly simple if we rely on the fact that `Task.async` reports the result back to the caller process via a message. We can therefore receive a message, and check if it comes from one of our task. If so, we can add the result to the aggregator.

To do this, we can rely on `Task.find/2` that takes the list of tasks and the message, and returns either `{result, task}` if the message corresponds to the task in the list, or `nil` if the message is not from a task in the given list:

```elixir
defmodule AsyncFind do
  def run do
    :random.seed(:os.timestamp)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) end)
    |> Enum.map(&Task.async(fn -> Computation.run(&1) end))
    |> collect_results
  end

  defp collect_results(tasks, aggregator \\ Aggregator.new)

  defp collect_results([], aggregator), do: Aggregator.value(aggregator)
  defp collect_results(tasks, aggregator) do
    receive do
      msg ->
        case Task.find(tasks, msg) do
          {result, task} ->
            collect_results(
              List.delete(tasks, task),
              Aggregator.add_result(aggregator, result)
            )

          nil ->
            collect_results(tasks, aggregator)
        end
    end
  end
end
```
Most of the action happens in `collect_results`. Here, we loop recursively, waiting for a message to arrive. Then we invoke `Task.find/2` to determine whether the message comes from a task. If yes, we delete the task from the list of pending tasks, aggregate the response and resume the loop. The loop stops when there are no more pending tasks in the list. Then, we simply return the aggregated value.

In this example I'm using explicit receive, but in production you should be careful about it. If the master process is a server, such as `GenServer` or `Phoenix.Channel`, you should let the underlying behaviour receive messages, and invoke `Task.find/2` from the `handle_info` callback. For the sake of brevity, I didn't take that approach here, but as an exercise you could try to implement it yourself.

One final note: by receiving results as they arrive we lose the ordering. In this case, where we simply sum numbers, this doesn't matter. If you must preserve the ordering, you'll need to include an additional order info, and then sort the results after they are collected.

## Handling timeouts
Once we moved away from `Task.await`, the master process becomes more flexible. For example, we can now easily introduce a global timeout. The idea is simple: after the tasks are started, we can use `Process.send_after/3` to send a message to the master process after some time:

```elixir
defmodule Timeout do
  def run do
    # exactly the same as before
  end

  defp collect_results(tasks) do
    timeout_ref = make_ref
    timer = Process.send_after(self, {:timeout, timeout_ref}, 900)
    try do
      collect_results(tasks, Aggregator.new, timeout_ref)
    after
      :erlang.cancel_timer(timer)
      receive do
        {:timeout, ^timeout_ref} -> :ok
        after 0 -> :ok
      end
    end
  end

  # ...
end
```
Here, we create the timer, and a reference which will be a part of the timeout message. Then we enqueue the timeout message to be sent to the master process after 900 ms. Including the reference in the message ensures that the timeout message will be unique for this run, and will not interfere with some other message.

Finally, we start the receive loop and return it's result.

Take special note of the `after` block where we cancel the timer to avoid sending a timeout message if all the results arrive on time. However, since timer works concurrently to the master process, it is still possible that the message might have been sent just before we canceled the timer, but after all the results are already collected. Thus, we do a receive with a zero timeout to flush the message if it's already in the queue.

With this setup in place, we now need to handle the timeout message:

```elixir
defp collect_results([], aggregator, _), do: {:ok, Aggregator.value(aggregator)}
defp collect_results(tasks, aggregator, timeout_ref) do
  receive do
    {:timeout, ^timeout_ref} ->
      {:timeout, Aggregator.value(aggregator)}

    msg ->
      case Task.find(tasks, msg) do
        {result, task} ->
          collect_results(
            List.delete(tasks, task),
            Aggregator.add_result(aggregator, result),
            timeout_ref
          )

        nil -> collect_results(tasks, aggregator, timeout_ref)
      end
  end
end
```
The core change here is in lines 4-5 where we explicitly deal with the timeout. In this example, we just return what we currently have. Depending on the particular use case, you may want to do something different, for example raise an error.

## Explicitly handling errors
The next thing we'll tackle is error handling. `Task.async` is built in such a way that if something fails, everything fails. When you start the task via `async` the process will be linked to the caller. This holds even if you use `Task.Supervisor.async`. As the result, if some task crashes, the master process will crash as well, taking down all other tasks.

If this is not a problem, then `Task.async` is a perfectly valid solution. However, sometimes you may want to explicitly deal with errors. For example, you might want to just ignore failing tasks, reporting back whatever succeeded. Or you may want to keep the tasks running even if the master process crashes.

There are two basic ways you can go about it: catch errors in the task, or use `Task.Supervisor` with `start_child`.

### Catching errors
The simplest approach is to encircle the task code with a `try/catch` block:

```elixir
Task.async(fn ->
  try do
    {:ok, Computation.run(...)}
  catch _, _ ->
    :error
  end
end)
```

Then, when you receive results, you can explicitly handle each case, ignoring `:error` results. The implementation is mostly mechanical and left to you as an exercise.

I've occasionally seen some concerns that catching is not the Erlang/Elixir way, so I'd like to touch on this. If you can do something meaningful with an error, catching is a reasonable approach. In this case, we want to collect all the successful responses, so ignoring failed ones is completely fine.

So catching is definitely a simple way of explicitly dealing with errors, but it's not without shortcomings. The main issue is that catch doesn't handle exit signals. Thus, if the task links to some other process, and that other process terminates, the task process will crash as well. Since the task is linked to the master process, this will cause the master process to crash, and in turn crash all other tasks. The link between the caller and the task also means that if the master process crashes, for example while aggregating, all tasks will be terminated.

To overcome this, we can either make all processes trap exits, or remove the link between processes. Trapping exits might introduce some subtle issues (see [here](https://www.reddit.com/r/elixir/comments/3dlwhu/is_it_ok_to_trap_exits_in_a_cowboy_handler_process) for some information), so I'll take the second approach.

### Replacing async
The whole issue arises because `async` links the caller and the task process, which ensures "all-or-nothing" property. This is a perfectly fine decision, but it's not necessarily suitable for all cases. I wonder whether linking should be made optional, but I don't have a strong opinion at the moment.

As it is, `Task.async` currently establishes a link, and if we want to avoid this, we need to reimplement async ourselves. Here's what we'll do:

- Start a `Task.Supervisor` and use `Task.Supervisor.start_child` to start tasks.
- Manually implement sending of the return message from the task to the caller.
- Have the master process monitor tasks so it can be notified about potential crashes. Explicitly handle such messages by removing the crashed task from the list of tasks we await on.

The first point allows us to run tasks in a different part of the supervision tree from the master. Tasks and the master process are no longer linked, and failure of one process doesn't cause failure of others.

However, since we're not using `async` anymore, we need to manually send the return message to the caller process.

Finally, using the monitor ensures that the master process will be notified if some task crashes and can stop awaiting on their results.

This requires more work, but it provides stronger guarantees. We can now be certain that:

- A failing task won't crash anyone else.
- The master process will be informed about the task crash and can do something about it.
- Even a failure of master process won't cause tasks to crash.

If the third property doesn't suit your purposes, you can simply place the master process and the tasks supervisor under the same common supervisor, with `one_for_all` or `rest_for_one` strategy.

This is what I like about Erlang fault-tolerance approach. There are various options with strong guarantees. You can isolate crashes, but you can also connect failures if needed. Some scenarios may require more work, but the implementation is still straightforward. Supporting these scenarios without process isolation and crash propagation would be harder and you might end up reinventing parts of Erlang.

Let's implement this. The top-level `run/0` function is now changed a bit:

```elixir
defmodule SupervisedTask do
  def run do
    :random.seed(:os.timestamp)
    Task.Supervisor.start_link(name: :task_supervisor)

    work_ref = make_ref

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) - 500 end)
    |> Enum.map(&start_computation(work_ref, &1))
    |> collect_results(work_ref)
  end

  # ...
end
```
First, a named supervisor is started. This is a quick hack to keep the example short. In production, this supervisor should of course reside somewhere in the supervision hierarchy.

Then, a _work reference_ is created, which will be included in task response messages. Finally, we generate some random numbers and start our computations. Notice the `:random.uniform(1000) - 500`. This ensures that some numbers will be negative, which will cause some tasks to crash.

Tasks now have to be started under the supervisor:

```elixir
defp start_computation(work_ref, arg) do
  caller = self

  # Start the task under the named supervisor
  {:ok, pid} = Task.Supervisor.start_child(
    :task_supervisor,
    fn ->
      result = Computation.run(arg)

      # Send the result back to the caller
      send(caller, {work_ref, self, result})
    end
  )

  # Monitor the started task
  Process.monitor(pid)
  pid
end
```
Finally, we need to expand the receive loop to handle `:DOWN` messages, which we'll receive when the task terminates:

```elixir
defp collect_results(tasks, work_ref) do
  timeout_ref = make_ref
  timer = Process.send_after(self, {:timeout, timeout_ref}, 400)
  try do
    collect_results(tasks, work_ref, Aggregator.new, timeout_ref)
  after
    :erlang.cancel_timer(timer)
    receive do
      {:timeout, ^timeout_ref} -> :ok
      after 0 -> :ok
    end
  end
end

defp collect_results([], _, aggregator, _), do: {:ok, Aggregator.value(aggregator)}
defp collect_results(tasks, work_ref, aggregator, timeout_ref) do
  receive do
    {:timeout, ^timeout_ref} ->
      {:timeout, Aggregator.value(aggregator)}

    {^work_ref, task, result} ->
      collect_results(
        List.delete(tasks, task),
        work_ref,
        Aggregator.add_result(aggregator, result),
        timeout_ref
      )

    {:DOWN, _, _, pid, _} ->
      if Enum.member?(tasks, pid) do
        # Handling task termination. In this case, we simply delete the
        # task from the list of tasks, and wait for other tasks to finish.
        collect_results(List.delete(tasks, pid), work_ref, aggregator, timeout_ref)
      else
        collect_results(tasks, work_ref, aggregator, timeout_ref)
      end
  end
end
```
This is mostly straightforward, with the major changes happening in lines 29-36. It's worth mentioning that we'll receive a `:DOWN` message even if the task doesn't crash. However, this message will arrive after the response message has been sent back, so the master process will first handle the response message. Since we remove the task from the list, the subsequent `:DOWN` message of that task will be ignored. This is not super efficient, and we could have improved this by doing some extra bookkeeping and demonitoring the task after it returns, but I refrained from this for the sake of brevity.

In any case, we can now test it. If I start `SupervisedTask.run`, I'll see some errors logged (courtesy of `Logger`), but I'll still get whatever is collected. You can also try it yourself. The code is available [here](https://github.com/sasa1977/beyond_task_async).

## Reducing the boilerplate
As we moved to more complex patterns, our master process became way more involved. The plain async/await has only 12 lines of code, while the final implementation has 66. The master process is burdened with a lot of mechanics, such as keeping references, starting a timer message, and handling received messages. There's a lot of potential to extract some of that boilerplate, so we can keep the master process more focused.

There are different approaches to extracting the boilerplate. If a process has to behave in a special way, you can consider creating a generic OTP-like behaviour that powers the process. The concrete implementation then just has to fill in the blanks by providing necessary callback functions.

However, in this particular case, I don't think creating a behaviour is a good option. The thing is that the master process might already be powered by a behaviour, such as `GenServer` or `Phoenix.Channel`. If we implement our generic code as a behaviour, we can't really combine it with another behaviour. Thus, we'll always need to have one more process that starts all these tasks and collects their results. This may result in excessive message passing, and have an impact on performance.

An alternative is to implement a helper module that can be used to start tasks and process task related messages. For example, we could have the following interface for starting tasks:

```elixir
runner = TaskRunner.run(
  [
    {:supervisor1, {SomeModule, :some_function, args}},
    {:supervisor2, {AnotherModule, :some_function, other_args}},
    {:supervisor3, fn -> ... end},
    # ...
  ],
  timeout
)
```
Under the hood, `TaskRunner` would start tasks under given supervisors, setup work and timer references, and send the timeout message to the caller process. By allowing different tasks to run under different supervisors, we have more flexibility. In particular, this allows us to start different tasks on different nodes.

The responsibility of receiving messages now lies on the caller process. It has to receive a message either via `receive` or for example in the `handle_info` callback. When the process gets a message, it has to first pass it to `TaskRunner.handle_message` which will return one of the following:

- `nil` - a message is not task runner specific, feel free to handle it yourself
- `{{:ok, result}, runner}` - a result arrived from a task
- `{{:task_error, reason}, runner}` - a task has crashed
- `{:timeout, runner}` - timeout has occurred

Finally, we'll introduce a `TaskRunner.done?/1` function, which can be used to determine whether all tasks have finished.

This is all we need to make various decision in the client process. The previous example can now be rewritten as:

```elixir
defmodule TaskRunnerClient do
  def run do
    :random.seed(:os.timestamp)
    Task.Supervisor.start_link(name: :task_supervisor)

    1..10
    |> Enum.map(fn(_) -> :random.uniform(1000) - 500 end)
    |> Enum.map(&{:task_supervisor, {Computation, :run, [&1]}})
    |> TaskRunner.run(400)
    |> handle_messages(Aggregator.new)
  end


  defp handle_messages(runner, aggregator) do
    if TaskRunner.done?(runner) do
      {:ok, Aggregator.value(aggregator)}
    else
      receive do
        msg ->
          case TaskRunner.handle_message(runner, msg) do
            nil -> handle_messages(runner, aggregator)

            {{:ok, result}, runner} ->
              handle_messages(runner, Aggregator.add_result(aggregator, result))

            {{:task_error, _reason}, runner} ->
              handle_messages(runner, aggregator)

            {:timeout, _runner} ->
              {:timeout, Aggregator.value(aggregator)}
          end
      end
    end
  end
end
```
This is less verbose than the previous version, and the receive loop is now focused only on handling of success, error, and timeout, without worrying how these situations are detected.

The code is still more involved than the simple async/await pattern, but it offers more flexibility. You can support various scenarios, such as stopping on first success or reporting the timeout back to the user while letting the tasks finish their jobs. If this flexibility is not important for your particular scenarios, then this approach is an overkill, and async/await should do just fine.

I will not describe the implementation of `TaskRunner` as it is mostly a refactoring of the code from `SupervisedTask`. You're advised to try and implement it yourself as an exercise. A basic (definitely not complete or tested) take can be found [here](https://github.com/sasa1977/beyond_task_async/blob/master/lib/task_runner.ex).

## Parting words
While this article focuses on tasks, in a sense they serve more as an example to illustrate concurrent thinking in Erlang.

Stepping away from `Task.await` and receiving messages manually allowed the master process to be more flexible. Avoiding links between master and the tasks decoupled their lives, and gave us a better error isolation. Using monitors made it possible to detect failures and perform some special handling. Pushing everything to a helper module, without implementing a dedicated behaviour, gave us the generic code that can be used in different types of processes.

These are in my opinion more important takeaways of this article. In the future the Elixir team may introduce additional support for tasks which will make most of these techniques unnecessary. But the underlying reasoning should be applicable in many other situations, not necessarily task-related.