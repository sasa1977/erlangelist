It's time to continue our exploration of Elixir macros. [Last time](/article/macros_3) I've covered some essential theory, and today, I'll step into a less documented territory, and discuss some details on Elixir AST.

## Tracing function calls
So far you have seen only basic macros that take input AST fragments and combine them together, sprinkling some additional boilerplate around and/or between input fragments. Since we don't analyze or parse the input AST, this is probably the cleanest (or the least hackiest) style of macro writing, which results in fairly simple macros that are reasonably easy to understand.

However, in some cases we will need to parse input AST fragments to get some specific informations. A simple example are `ExUnit` assertions. For example, the expression `assert 1+1 == 2+2` will fail with an error:

```elixir
Assertion with == failed
code: 1+1 == 2+2
lhs:  1
rhs:  2
```
The macro `assert` accepts the entire expression `1+1 == 2+2` and is able to extract individual sub-expressions of the comparison, printing their corresponding results if the entire expression returns false. To do this, the macro code must somehow split the input AST into separate parts and compute each sub-expression separately.

In more involved cases even richer AST transformations are called for. For example, with ExActor you can write this code:

```elixir
defcast inc(x), state: state, do: new_state(state + x)
```
which translates to roughly the following:

```elixir
def inc(pid, x) do
  :gen_server.cast(pid, {:inc, x})
end

def handle_cast({:inc, x}, state) do
  {:noreply, state+x}
end
```

Just like `assert`, the `defcast` macro needs to dive into the input AST fragment and detect individual sub-fragments (e.g. function name, individual arguments). Then, ExActor performs an elaborate transformation, reassembling this sub-parts into a more complex code.

Today, I'm going to show you some basic techniques of building such macros, and I'll continue with more complex transformations in subsequent articles. But before doing this, I should advise you to carefully consider whether your code needs to be based on macros. Though very powerful, macros have some downsides.

First, as you'll see in this series, the code can quickly become much more involved than "plain" run-time abstractions. You can quickly end up doing many nested `quote`/`unquote` calls and weird pattern matches that rely on undocumented format of the AST.

In addition, proliferation of macros may make your client code extremly cryptic, since it will rely on custom, non-standard idioms (such as `defcast` from ExActor). It can become harder to reason about the code, and understand what exactly happens underneath.

On the plus side, macros can be very helpful when removing boilerplate (as hopefully ExActor example demonstrated), and have the power of accessing information that is not available at run-time (as you should see from the `assert` example). Finally, since they run during compilation, macros make it possible to optimize some code by moving calculations to compile-time.

So there will definitely be cases that are suited for macros, and you shouldn't be afraid of using them. However, you shouldn't choose macros only to gain some cute DSL-ish syntax. Before reaching for macros, you should consider whether your problem can be solved efficiently in run-time, relying on "standard" language abstractions such as functions, modules, and protocols.

## Discovering the AST structure
At the moment of writing this there is very little documentation on the AST structure. However, it's easy to explore and play with AST in the shell session, and this is how I usually discover the AST format.

For example, here's how a quoted reference to a variable looks like:

```elixir
iex(1)> quote do my_var end
{:my_var, [], Elixir}
```
Here, the first element represents the name of the variable. The second element is a context keyword list that contains some metadata specific for this particular AST fragment (e.g. imports and aliases). Most often you won't be interested in context data. The third element usually represents the module where the quoting happened, and is used to ensure hygiene of quoted variables. If this element is `nil` then the identifier is not hygienic.

A simple expression looks a bit more involved:

```elixir
iex(2)> quote do a+b end
{:+, [context: Elixir, import: Kernel], [{:a, [], Elixir}, {:b, [], Elixir}]}
```
This might look scary, but it's reasonably easy to understand if I show you the higher-level pattern:

```elixir
{:+, context, [ast_for_a, ast_for_b]}
```
In our example, `ast_for_a` and `ast_for_b` follow the shape of a variable reference you've seen earlier (e.g. `{:a, [], Elixir}`. More generally, quoted arguments can be arbitrary complex since they describe the expression of each argument. Essentially, AST is a deep nested structure of simple quoted expressions such as the ones I'm showing you here.

Let's take a look at a function call:

```elixir
iex(3)> quote do div(5,4) end
{:div, [context: Elixir, import: Kernel], [5, 4]}
```
This resembles the quoted `+` operation, which shouldn't come as a surprise knowing that `+` [is actually a function](https://github.com/elixir-lang/elixir/blob/v0.14.0/lib/elixir/lib/kernel.ex#L856). In fact, all binary operators will be quoted as function calls.

Finally, let's take a look at a quoted function definition:

```elixir
iex(4)> quote do def my_fun(arg1, arg2), do: :ok end
{:def, [context: Elixir, import: Kernel],
 [{:my_fun, [context: Elixir], [{:arg1, [], Elixir}, {:arg2, [], Elixir}]},
  [do: :ok]]}
```
While this looks scary, it can be simplified by looking at important parts. Essentially, this deep structure amounts to:

```elixir
{:def, context, [fun_call, [do: body]]}
```
with `fun_call` having the structure of a function call (which you've just seen).

As you can see, there usually is some reason and sense behind the AST. I won't go through all possible AST shapes here, but the approach to discovery is to play in `iex` and quote simpler forms of expressions you're interested in. This is a bit of reverse engineering, but it's not exactly a rocket science.

## Writing assert macro
For a quick demonstration, let's write a simplified version of the `assert` macro. This is an interesting macro because it literally reinterprets the meaning of comparison operators. Normally, when you write `a == b` you get a boolean result. However, when this expression is given to the `assert` macro, a detailed output is printed if the expression evaluates to `false`.

I'll start simple, by supporting only `==` operator in the macro. To recap, when we call `assert expected == required`, it's the same as calling `assert(expected == required)`, which means that our macro receives a quoted fragment that represents comparison. Let's discover the AST structure of this comparison:

```elixir
iex(1)> quote do 1 == 2 end
{:==, [context: Elixir, import: Kernel], [1, 2]}

iex(2)> quote do a == b end
{:==, [context: Elixir, import: Kernel], [{:a, [], Elixir}, {:b, [], Elixir}]}
```
So our structure is essentially, `{:==, context, [quoted_lhs, quoted_rhs]}`. This should not be surprising if you remember the examples shown in previous section, where I've mentioned that binary operators are quoted as two arguments function calls.

Knowing the AST shape, it's relatively simple to write the macro:

```elixir
defmodule Assertions do
  defmacro assert({:==, _, [lhs, rhs]} = expr) do
    quote do
      left = unquote(lhs)
      right = unquote(rhs)

      result = (left == right)

      unless result do
        IO.puts "Assertion with == failed"
        IO.puts "code: #{unquote(Macro.to_string(expr))}"
        IO.puts "lhs: #{left}"
        IO.puts "rhs: #{right}"
      end

      result
    end
  end
end
```
The first interesting thing happens in line 2. Notice how we pattern match on the input expression, expecting it to conform to some structure. This is perfectly fine, since macros are functions, which means you can rely on pattern matching, guards, and even have multi-clause macros. In our case, we rely on pattern matching to take each (quoted) side of the comparison expression into corresponding variables.

Then, in the quoted code, we reinterpret the `==` operation by computing left- and right-hand side  individually, (lines 4 and 5), and then the entire result (line 7). Finally, if the result is false, we print detailed informations (lines 9-14).

Let's try it out:

```elixir
iex(1)> defmodule Assertions do ... end
iex(2)> import Assertions

iex(3)> assert 1+1 == 2+2
Assertion with == failed
code: 1 + 1 == 2 + 2
lhs: 2
rhs: 4
```

## Generalizing the code
It's not much harder to make the code work for other operators:

```elixir
defmodule Assertions do
  defmacro assert({operator, _, [lhs, rhs]} = expr)
    when operator in [:==, :<, :>, :<=, :>=, :===, :=~, :!==, :!=, :in]
  do
    quote do
      left = unquote(lhs)
      right = unquote(rhs)

      result = unquote(operator)(left, right)

      unless result do
        IO.puts "Assertion with #{unquote(operator)} failed"
        IO.puts "code: #{unquote(Macro.to_string(expr))}"
        IO.puts "lhs: #{left}"
        IO.puts "rhs: #{right}"
      end

      result
    end
  end
end
```

There are only a couple of changes here. First, in the pattern-match, the hard-coded `:==` is replaced with the `operator` variable (line 2).

I've also introduced (or to be honest, copy-pasted from Elixir source) guards specifying the set of operators for which the macro works (line 3). There is a special reason for this check. Remember how I earlier mentioned that quoted `a + b` (and any other binary operation) has the same shape as quoted `fun(a,b)`. Consequently, without these guards, every two-arguments function call would end up in our macro, and this is something we probably don't want. Using this guard limits allowed inputs only to known binary operators.

The interesting thing happens in line 9. Here I make a simple generic dispatch to the operator using `unquote(operator)(left, right)`. You might think that I could have instead used `left unquote(operator) right`, but this wouldn't work. The reason is that `operator` variable holds an atom (e.g. `:==`). Thus, this naive quoting would produce `left :== right`, which is not even a proper Elixir syntax.

Keep in mind that while quoting, we don't assemble strings, but AST fragments. So instead, when we want to generate a binary operation code, we need to inject a proper AST, which (as explained earlier) is the same as the two arguments function call. Hence, we can simply generate the function call `unquote(operator)(left, right)`.

With this in mind, I'm going to finish today's session. It was a bit shorter, but slightly more complex. [Next time](/article/macros_4), I'm going to dive a bit deeper into the topic of AST parsing.