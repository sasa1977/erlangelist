Today's post is the last one in the macro series. Before starting, I'd like to extend kudos to [Björn Rochel](https://twitter.com/BjoernRochel) who already improved on `deftraceable` macro in his [Apex](https://github.com/BjRo/apex) library. Björn discovered that the blog version of `deftraceable` doesn't handle default args (`arg \\ def_value`) properly, and [implemented a fix](https://github.com/BjRo/apex/blob/ca3cfbcf4473a4314d8dfa7f4bed610be652a03b/lib/apex/awesome_def.ex#L57-L59).

In the meantime, let's wrap up this macro saga. In today's post, probably the most involved one in the entire series, I'm going to discuss some aspects of an in-place code generation, and the consequences it may have on our macros.

## Generating code in the module
As I mentioned way back in [part 1](macros_1), macros are not the only meta-programming mechanism in Elixir. It is also possible to generate the code directly in the module. To refresh your memory, let's see the example:

```elixir
defmodule Fsm do
  fsm = [
    running: {:pause, :paused},
    running: {:stop, :stopped},
    paused: {:resume, :running}
  ]

  # Dynamically generating functions directly in the module
  for {state, {action, next_state}} <- fsm do
    def unquote(action)(unquote(state)), do: unquote(next_state)
  end
  def initial, do: :running
end

Fsm.initial
# :running

Fsm.initial |> Fsm.pause
# :paused

Fsm.initial |> Fsm.pause |> Fsm.pause
# ** (FunctionClauseError) no function clause matching in Fsm.pause/1
```
Here, we're dynamically generating function clauses directly in the module. This allows us to metaprogram against some input (in this case a keyword list), and generate the code without writing a dedicated macro.

Notice in the code above how we use `unquote` to inject variables into function clause definition. This is perfectly in sync with how macros work. Keep in mind that `def` is also a macro, and a macro always receives it's arguments quoted. Consequently, if you want a macro argument to receive the value of some variable, you must use `unquote` when passing that variable. It doesn't suffice to simply call `def action`, because `def` macro receives a quoted reference to `action` rather than value that is in the variable `action`.

You can of course call your own macros in such dynamic way, and the same principle will hold. There is an unexpected twist though - the order of evaluation is not what you might expect.

## Order of expansion
As you'd expect, the module-level code (the code that isn't a part of any function) is evaluated in the expansion phase. Somewhat surprisingly, this will happen after all macros (save for `def`) have been expanded. It's easy to prove this:

```elixir
iex(1)> defmodule MyMacro do
          defmacro my_macro do
            IO.puts "my_macro called"
            nil
          end
        end

iex(2)> defmodule Test do
          import MyMacro

          IO.puts "module-level expression"
          my_macro
        end

# Output:
my_macro called
module-level expression
```
See from the output how `mymacro` is called before `IO.puts` even though the corresponding `IO.puts` call precedes the macro call. This proves that compiler first resolves all "standard" macros. Then the module generation starts, and it is in this phase where module-level code, together with calls to `def` is being evaluated.

## Module-level friendly macros
This has some important consequences on our own macros. For example, our `deftraceable` macro could also be invoked dynamically. However, this currently won't work:

```elixir
iex(1)> defmodule Tracer do ... end

iex(2)> defmodule Test do
          import Tracer

          fsm = [
            running: {:pause, :paused},
            running: {:stop, :stopped},
            paused: {:resume, :running}
          ]

          for {state, {action, next_state}} <- fsm do
            # Using deftraceable dynamically
            deftraceable unquote(action)(unquote(state)), do: unquote(next_state)
          end
          deftraceable initial, do: :running
        end

** (MatchError) no match of right hand side value: :error
    expanding macro: Tracer.deftraceable/2
    iex:13: Test (module)
```
This falls with a somewhat cryptic and not very helpful error. So what went wrong? As mentioned in previous section, macros are expanded before in-place module evaluation starts. For us this means that `deftraceable` is called before the outer `for` comprehension is even evaluated.

Consequently, __even though it is invoked from a comprehension, `deftraceable` will be invoked exactly once__. Moreover, since comprehension is not yet evaluated, inner variables `state`, `action`, and `next_state` are not present when our macro is called.

How can this even work? Essentially, our macro will be called with quoted unquote - `head` and `body` will contain ASTs that represents `unquote(action)(unquote(state))` and `unquote(next_state)` respectively.

Now, recall that in the current version of `deftraceable`, we make some assumptions about input in our macro. Here's a sketch:

```elixir
defmacro deftraceable(head, body) do
  # Here, we are assuming how the input head looks like, and perform some
  # AST transformations based on those assumptions.

  quote do
    ...
  end
end
```
And that's our problem. If we call `deftraceable` dynamically, while generating the code in-place, then such assumptions no longer hold.

## Deferring code generation
When it comes to macro execution, it's important to distinguish between the macro context and the caller's context:

```elixir
defmacro my_macro do
  # Macro context: the code here is a normal part of the macro, and runs when
  # the macro is invoked.

  quote do
    # Caller's context: generated code that runs in place where the macro is
    # invoked.
  end
```
This is where things get a bit tricky. If we want to support module-level dynamic calls of our macros, we shouldn't assume anything in the macro context. Instead, we should defer the code generation to the caller's context.

To say it in code:

```elixir
defmacro deftraceable(head, body) do
  # Macro context: we shouldn't assume anything about the input AST here

  quote do
    # Caller's context: we should transfer input AST here, and then make our
    # assumptions here.
  end
end
```
Why can we make assumptions in the caller's context? Because this code will run after all macros have been expanded. For example, remember that even though our macro is invoked from inside a comprehension, it will be called only once. However, the code generated by our macro will run in the comprehension - once for each element.

So this approach amounts to deferring the final code generation. Instead of immediately generating the target code, we generate intermediate module-level statements that will generate the final code. These intermediate statements will run at the latest possible moment of expansion, after all other macros have been resolved:

```elixir
defmodule Test do
  ...

  for {state, {action, next_state}} <- fsm do
    # After deftraceable is expanded, here we'll get a plain code that
    # generates target function. This code will be invoked once for
    # every step of the for comprehension. At this point, we're in the
    # caller's context, and have an access to state, action, and next_state
    # variables and can properly generate corresponding function.
  end

  ...
end
```
Before implementing the solution, it's important to note that this is not a universal pattern, and you should consider whether you really need this approach.

If your macro is not meant to be used on a module-level, then you should probably avoid this technique. Otherwise, if your macro is called from inside function definition, and you move the generation to the caller's context, you'll essentially move the code execution from compile-time to run-time, which can affect performance.

Moreover, even if your macro is running on a module-level, this technique won't be necessary as long as you don't make any assumptions about the input. For example, in [part 2](macros_2), we made a simulation of Plug's `get` macro:

```elixir
defmacro get(route, body) do
  quote do
    defp do_match("GET", unquote(route), var!(conn)) do
      unquote(body[:do])
    end
  end
end
```
Even though this macro works on a module-level it doesn't assume anything about the format of the AST, simply injecting input fragments in the caller's context, sprinkling some boilerplate around. Of course, we're expecting here that `body` will have a `:do` option, but we're not assuming anything about the specific shape and format of `body[:do]` AST.

To recap, if your macro is meant to be called on a module-level, this could be the general pattern:

```elixir
defmacro ...
  # Macro context:
  # Feel free to do any preparations here, as long as you don't assume anything
  # about the shape of the input AST

  quote do
    # Caller's context:
    # If you're analyzing and/or transforming input AST you should do it here.
  end
```
Since the caller context is module-level, this deferred transformation will still take place in compilation time, so there will be no runtime performance penalties.

## The solution
Given this discussion, the solution is relatively simple, but explaining it is fairly involved. So I'm going to start by showing you the end result (pay attention to comments):

```elixir
defmodule Tracer do
  defmacro deftraceable(head, body) do
    # This is the most important change that allows us to correctly pass
    # input AST to the caller's context. I'll explain how this works a
    # bit later.
    quote bind_quoted: [
      head: Macro.escape(head, unquote: true),
      body: Macro.escape(body, unquote: true)
    ] do
      # Caller's context: we'll be generating the code from here

      # Since the code generation is deferred to the caller context,
      # we can now make our assumptions about the input AST.

      # This code is mostly identical to the previous version
      #
      # Notice that these variables are now created in the caller's context.
      {fun_name, args_ast} = Tracer.name_and_args(head)
      {arg_names, decorated_args} = Tracer.decorate_args(args_ast)

      # Completely identical to the previous version.
      head = Macro.postwalk(head,
        fn
          ({fun_ast, context, old_args}) when (
            fun_ast == fun_name and old_args == args_ast
          ) ->
            {fun_ast, context, decorated_args}
          (other) -> other
      end)

      # This code is completely identical to the previous version
      # Note: however, notice that the code is executed in the same context
      # as previous three expressions.
      #
      # Hence, the unquote(head) here references the head variable that is
      # computed in this context, instead of macro context. The same holds for
      # other unquotes that are occuring in the function body.
      #
      # This is the point of deferred code generation. Our macro generates
      # this code, which then in turn generates the final code.
      def unquote(head) do
        file = __ENV__.file
        line = __ENV__.line
        module = __ENV__.module

        function_name = unquote(fun_name)
        passed_args = unquote(arg_names) |> Enum.map(&inspect/1) |> Enum.join(",")

        result = unquote(body[:do])

        loc = "#{file}(line #{line})"
        call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
        IO.puts "#{loc} #{call}"

        result
      end
    end
  end

  # Identical to the previous version, but functions are exported since they
  # must be called from the caller's context.
  def name_and_args({:when, _, [short_head | _]}) do
    name_and_args(short_head)
  end

  def name_and_args(short_head) do
    Macro.decompose_call(short_head)
  end

  def decorate_args([]), do: {[],[]}
  def decorate_args(args_ast) do
    for {arg_ast, index} <- Enum.with_index(args_ast) do
      arg_name = Macro.var(:"arg#{index}", __MODULE__)

      full_arg = quote do
        unquote(arg_ast) = unquote(arg_name)
      end

      {arg_name, full_arg}
    end
    |> List.unzip
    |> List.to_tuple
  end
end
```
Let's try the macro:

```elixir
iex(1)> defmodule Tracer do ... end

iex(2)> defmodule Test do
          import Tracer

          fsm = [
            running: {:pause, :paused},
            running: {:stop, :stopped},
            paused: {:resume, :running}
          ]

          for {state, {action, next_state}} <- fsm do
            deftraceable unquote(action)(unquote(state)), do: unquote(next_state)
          end
          deftraceable initial, do: :running
        end

iex(3)> Test.initial |> Test.pause |> Test.resume |> Test.stop

iex(line 15) Elixir.Test.initial() = :running
iex(line 13) Elixir.Test.pause(:running) = :paused
iex(line 13) Elixir.Test.resume(:paused) = :running
iex(line 13) Elixir.Test.stop(:running) = :stopped
```
As you can see, the change is not very complicated. We managed to keep most of our code intact, though we had to do some trickery with `quote bind_quoted: true` and `Macro.escape`:

```elixir
quote bind_quoted: [
  head: Macro.escape(head, unquote: true),
  body: Macro.escape(body, unquote: true)
] do
  ...
end
```
Let's take a closer look at what does it mean.

## bind_quoted
Remember that our macro is generating a code that will generate the final code. Somewhere in the first-level generated code (the one returned by our macro), we need to place the following expression:

```elixir
def unquote(head) do ... end
```
This expression will be invoked in the caller's context (the client module), and its task is to generate the function. As mentioned in comments, it's important to understand that `unquote(head)` here references the `head` variable that exists in the caller's context. We're not injecting a variable from the macro context, but the one that exists in the caller's context.

However, we can't generate such expression with plain `quote`:

```elixir
quote do
  def unquote(head) do ... end
end
```
Remember how `unquote` works. It injects the AST that is in the `head` variable in place of the `unquote` call. This is not what we want here. What we want is to generate the AST representing the call to `unquote` which will then be executed later, in the caller's context, and reference the caller's `head` variable.

This can be done by providing `unquote: false` option:

```elixir
quote unquote: false do
  def unquote(head) do ... end
end
```
Here, we will generate the code that represents `unquote` call. If this code is injected in proper place, where variable `head` exists, we'll end up calling the `def` macro, passing whatever is in the `head` variable.

So it seems that `unquote: false` is what we need, but there is a downside that we can't access any variable from the macro context:

```elixir
foo = :bar
quote unquote: false do
  unquote(foo)    # <- won't work because of unquote: false
end
```
Using `unquote: false` effectively blocks immediate AST injection, and treats `unquote` as any other function call. Consequently, we can't inject something into the target AST. And here's where `bind_quoted` comes in handy. By providing `bind_quoted: bindings` we can disable immediate unquoting, while still binding whatever data we want to transfer to the caller's context:

```elixir
quote bind_quoted: [
  foo: ...,
  bar: ...
] do
  unquote(whatever)  # <- works like with unquote: false

  foo  # <- accessible due to bind_quoted
  bar  # <- accessible due to bind_quoted
end
```
## Injecting the code vs transferring data
Another problem we're facing is that the contents we're passing from the macro to the caller's context is by default _injected_, rather then transferred. So, whenever you do `unquote(some_ast)`, you're injecting one AST fragment into another one you're building with a `quote` expression.

Occasionally, we want to _transfer_ the data, instead of injecting it. Let's see an example. Say we have some triplet, we want to transfer to the caller's context

```elixir
iex(1)> data = {1, 2, 3}
{1, 2, 3}
```
Now, let's try to transfer it using typical `unquote`:

```elixir
iex(2)> ast = quote do IO.inspect(unquote(data)) end
{{:., [], [{:__aliases__, [alias: false], [:IO]}, :inspect]}, [], [{1, 2, 3}]}
```
This seems to work. Let's try and eval the resulting ast:

```elixir
iex(3)> Code.eval_quoted(ast)
** (CompileError) nofile: invalid quoted expression: {1, 2, 3}
```
So what happened here? The thing is that we didn't really transfer our `{1,2,3}` triplet. Instead, we injected it into the target AST. Injection means, that `{1,2,3}` is itself treated as an AST fragment, which is obviously wrong.

What we really want in this case is data transfer. In the code generation context, we have some data that we want to transfer to the caller's context. And this is where `Macro.escape` helps. By escaping a term, we can make sure that it is transferred rather than injected. When we call `unquote(Macro.escape(term))`, we'll inject an AST that describes the data in `term`.

Let's try this out:

```elixir
iex(3)> ast = quote do IO.inspect(unquote(Macro.escape(data))) end
{{:., [], [{:__aliases__, [alias: false], [:IO]}, :inspect]}, [],
 [{:{}, [], [1, 2, 3]}]}

iex(4)> Code.eval_quoted(ast)
{1, 2, 3}
```
As you can see, we were able to transfer the data untouched.

Going back to our deferred code generation, this is exactly what we need. Instead of injecting into the target AST, we want to transfer the input AST, completely preserving its shape:

```elixir
defmacro deftraceable(head, body) do
  # Here we have head and body AST
  quote do
    # We need that same head and body AST here, so we can generate
    # the final code.
  end
end
```
By using `Macro.escape/1` we can ensure that input AST is transferred untouched back to the caller's context where we'll generate the final code.

As discussed in previous section, we're using `bind_quoted`, but the same principle holds:

```elixir
quote bind_quoted: [
  head: Macro.escape(head, unquote: true),
  body: Macro.escape(body, unquote: true)
] do
  # Here we have exact data copies of head and body from
  # the macro context.
end
```

## Escaping and unquote: true
Notice a deceptively simple `unquote: true` option that we pass to `Macro.escape`. This is the hardest thing to explain here. To be able to understand it, you must be confident about how AST is passed to the macro, and returned back to the caller's context.

First, remember how we call our macro:

```elixir
deftraceable unquote(action)(unquote(state)) do ... end
```
Now, since macro actually receives its arguments quoted, the `head` argument will be equivalent to following:

```elixir
# This is what the head argument in the macro context actually contains
quote unquote: false do
  unquote(action)(unquote(state))
end
```
Remember that `Macro.escape` preserves data, so when you transfer a variable in some other AST, the contents remains unchanged. Given the shape of the `head` above, this is the situation we'll end up with after our macro is expanded:

```elixir
# Caller's context
for {state, {action, next_state}} <- fsm do
  # Here is our code that generates function. Due to bind_quoted, here
  # we have head and body variables available.

  # Variable head is equivalent to
  #   quote unquote: false do
  #     unquote(action)(unquote(state))
  #   end

  # What we really need is for head to be equivalent to:
  #   quote do
  #     unquote(action)(unquote(state))
  #   end
end
```
Why do we need the second form of quoted head? Because this AST is now shaped in the caller's context, where we have `action` and `state` variables available. And the second expression will use the contents of these variables.

And this is where `unquote: true` option helps. When we call `Macro.escape(input_ast, unquote: true)`, we'll still (mostly) preserve the shape of the transferred data, but the `unquote` fragments (e.g. `unquote(action)`) in the input AST will be resolved _in the caller's context_.

So to recap, a proper transport of the input AST to the caller's context looks like this:

```
defmacro deftraceable(head, body) do
  quote bind_quoted: [
    head: Macro.escape(head, unquote: true),
    body: Macro.escape(body, unquote: true)
  ] do
    # Generate the code here
  end
  ...
end
```
This wasn't so hard, but it takes some time grokking what exactly happens here. Try to make sure you're not just blindly doing escapes (and/or `unquote: true`) without understanding that this is what you really want. After all, there's a reason this is not a default behavior.

When writing a macro, think about whether you want to inject some AST, or transport the data unchanged. In the latter case, you need `Macro.escape`. If the data being transferred is an AST that might contain `unquote` fragments, then you probably need to use `Macro.escape` with `unquote: true`.

## Recap
This concludes the series on Elixir macros. I hope you found these articles interesting and educating, and that you have gained more confidence and understanding of how macros work.

Always remember - macros amount to plain composition of AST fragments during expansion phase. If you understand the caller's context and macro inputs, it shouldn't be very hard to perform the transformations you want either directly, or by deferring when necessary.

This series has by no means covered all possible aspects and nuances. If you want to learn more, a good place to start is the documentation for [quote/2 special form](http://elixir-lang.org/docs/stable/elixir/Kernel.SpecialForms.html#quote/2). You'll also find some useful helpers in the [Macro](http://elixir-lang.org/docs/stable/elixir/Macro.html) and [Code](http://elixir-lang.org/docs/stable/elixir/Code.html) module.

Happy meta-programming!