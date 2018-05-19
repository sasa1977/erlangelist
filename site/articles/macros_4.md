In [previous installment](macros_3), I've shown you some basic ways of analyzing input AST and doing something about it. Today we'll take a look at some more involved AST transformations. This will mostly be a rehash of already explained techniques. The aim is to show that it's not very hard to go deeper into the AST, though the resulting code can easily become fairly complex and somewhat hacky.

## Tracing function calls
In this article, we'll create a `deftraceable` macro that allows us to define traceable functions. A traceable function works just like a normal function, but whenever we call it, a debug information is printed. Here's the idea:

```elixir
defmodule Test do
  import Tracer

  deftraceable my_fun(a,b) do
    a/b
  end
end

Test.my_fun(6,2)

# => test.ex(line 4) Test.my_fun(6,2) = 3
```
This example is of course contrived. You don't need to devise such macro, because [Erlang already has very powerful tracing capabilities](http://erlang.org/doc/man/dbg.html), and there's an [Elixir wrapper available](https://github.com/fishcakez/dbg). However, the example is interesting because it will demand some deeper AST transformations and techniques.

Before starting, I'd like to mention again that you should carefully consider whether you really need such constructs. Macros such as `deftraceable` introduce another thing every code maintainer needs to understand. Looking at the code, it's not obvious what happens behind the scene. If everyone devises such constructs, each Elixir project will quickly turn into a soup of custom language extentions. It will be hard even for experienced developers to understand the flow of the underlying code that heavily relies on complex macros.

All that said, there will be cases suitable for macros, so you shouldn't avoid them just because someone claims that macros are bad. For example, if we didn't have tracing facilities in Erlang, we'd need to devise some kind of a macro to help us with it (not necesarilly similar to the example above, but that's another discussion), or our code would suffer from large boilerplate.

In my opinion, boilerplate is bad because the code becomes ridden with bureaucratic noise, and therefore it is harder to read and understand. Macros can certainly help in reducing crust, but before reaching for them, consider whether you can resolve duplication with run-time constructs (functions, modules, protocols).

With that long disclaimer out of the way, let's write `deftraceable`. First, it's worth manually generating the corresponding code.

Let's recall the usage:

```elixir
deftraceable my_fun(a,b) do
  a/b
end
```
The generated code should look like:

```elixir
def my_fun(a, b) do
  file = __ENV__.file
  line = __ENV__.line
  module = __ENV__.module
  function_name = "my_fun"
  passed_args = [a,b] |> Enum.map(&inspect/1) |> Enum.join(",")

  result = a/b

  loc = "#{file}(line #{line})"
  call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
  IO.puts "#{loc} #{call}"

  result
end
```
The idea is simple. We fetch various data from the compiler environment, then compute the result, and finally print everything to the screen.

The code relies on `__ENV__` special form that can be used to inject all sort of compile-time informations (e.g. line number and file) in the final AST. `__ENV__` is a struct and whenever you use it in the code, it will be expanded in compile time to appropriate value. Hence, wherever in code we write `__ENV__.file` the resulting bytecode will contain the (binary) string constant with the containing file name.

Now we need to build this code dynamically. Let's see the basic outline:

```elixir
defmacro deftraceable(??) do
  quote do
    def unquote(head) do
      file = __ENV__.file
      line = __ENV__.line
      module = __ENV__.module
      function_name = ??
      passed_args = ?? |> Enum.map(&inspect/1) |> Enum.join(",")

      result = ??

      loc = "#{file}(line #{line})"
      call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
      IO.puts "#{loc} #{call}"

      result
    end
  end
end
```
Here I placed question marks (??) in places where we need to dynamically inject AST fragments, based on the input arguments. In particular, we have to deduce function name, argument names, and function body from the passed parameters.

Now, when we call a macro `deftraceable my_fun(...) do ... end`, the macro receives two arguments - the function head (function name and argument list) and a keyword list containing the function body. Both of these will of course be quoted.

How do I know this? I actually don't. I usually gain this knowledge by trial and error. Basically, I start by defining a macro:

```elixir
defmacro deftraceable(arg1) do
  IO.inspect arg1
  nil
end
```
Then I try to call the macro from some test module or from the shell. If the argument numbers are wrong, an error will occur, and I'll retry by adding another argument to the macro definition. Once I get the result printed, I try to figure out what arguments represent, and then start building the macro.

The `nil` at the end of the macro ensures we don't generate anything (well, we generate `nil` which is usually irrelevant to the caller code). This allows me to further compose fragments without injecting the code. I usually rely on `IO.inspect` and `Macro.to_string/1` to verify intermediate results, and once I'm happy, I remove the `nil` part and see if the thing works.

In our case `deftraceable` receives the function head and the body. The function head will be an AST fragment in the format I've described last time (`{function_name, context, [arg1, arg2, ...]`).

So we need to do following:
- Extract function name and arguments from the quoted head
- Inject these values into the AST we're returning from the macro
- Inject function body into that same AST
- Print trace info

We could use pattern matching to extract function name and arguments from this AST fragment, but as it turns out there is a helper `Macro.decompose_call/1` that does exactly this. Given these steps, the final version of the macro looks like this:

```elixir
defmodule Tracer do
  defmacro deftraceable(head, body) do
    # Extract function name and arguments
    {fun_name, args_ast} = Macro.decompose_call(head)

    quote do
      def unquote(head) do
        file = __ENV__.file
        line = __ENV__.line
        module = __ENV__.module

        # Inject function name and arguments into AST
        function_name = unquote(fun_name)
        passed_args = unquote(args_ast) |> Enum.map(&inspect/1) |> Enum.join(",")

        # Inject function body into the AST
        result = unquote(body[:do])

        # Print trace info"
        loc = "#{file}(line #{line})"
        call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
        IO.puts "#{loc} #{call}"

        result
      end
    end
  end
end
```
Let's try it out:

```elixir
iex(1)> defmodule Tracer do ... end

iex(2)> defmodule Test do
          import Tracer

          deftraceable my_fun(a,b) do
            a/b
          end
        end

iex(3)> Test.my_fun(10,5)
iex(line 4) Test.my_fun(10,5) = 2.0   # trace output
2.0
```
It seems to be working. However, I should immediately point out that there are a couple of problems with this implementation:

- The macro doesn't handle guards well
- Pattern matching arguments will not always work (e.g. when using _ to match any term)
- The macro doesn't work when dynamically generating code directly in the module.

I'll explain each of these problems one by one, starting with guards, and leaving remaining issues for future articles.

## Handling guards
All problems with `deftraceable` stem from the fact that we're making some assumptions about the input AST. That's a dangerous teritory, and we must be careful to cover all cases.

For example, the macro assumes that head contains just the name and the arguments list. Consequently, `deftraceable` won't work if we want to define a traceable function with guards:

```elixir
deftraceable my_fun(a,b) when a < b do
  a/b
end
```
In this case, our head (the first argument of the macro) will also contain the guard information, and will not be parsable by `Macro.decompose_call/1` The solution is to detect this case, and handle it in a special way.

First, let's discover how this head is quoted:

```elixir
iex(1)> quote do my_fun(a,b) when a < b end
{:when, [],
 [{:my_fun, [], [{:a, [], Elixir}, {:b, [], Elixir}]},
  {:<, [context: Elixir, import: Kernel],
   [{:a, [], Elixir}, {:b, [], Elixir}]}]}
```
So essentially, our guard head has the shape of `{:when, _, [name_and_args, ...]}`. We can rely on this to extract the name and arguments using pattern matching:

```elixir
defmodule Tracer do
  ...
  defp name_and_args({:when, _, [short_head | _]}) do
    name_and_args(short_head)
  end

  defp name_and_args(short_head) do
    Macro.decompose_call(short_head)
  end
  ...
```
And of course, we need to call this function from the macro:

```elixir
defmodule Tracer do
  ...
  defmacro deftraceable(head, body) do
    {fun_name, args_ast} = name_and_args(head)

    ... # unchanged
  end
  ...
end
```
As you can see, it's possible to define additional private functions and call them from your macro. After all, a macro is just a function, and when it is called, the containing module is already compiled and loaded into the VM of the compiler (otherwise, macro couldn't be running).

Here's the full version of the macro:

```elixir
defmodule Tracer do
  defmacro deftraceable(head, body) do
    {fun_name, args_ast} = name_and_args(head)

    quote do
      def unquote(head) do
        file = __ENV__.file
        line = __ENV__.line
        module = __ENV__.module

        function_name = unquote(fun_name)
        passed_args = unquote(args_ast) |> Enum.map(&inspect/1) |> Enum.join(",")

        result = unquote(body[:do])

        loc = "#{file}(line #{line})"
        call = "#{module}.#{function_name}(#{passed_args}) = #{inspect result}"
        IO.puts "#{loc} #{call}"

        result
      end
    end
  end

  defp name_and_args({:when, _, [short_head | _]}) do
    name_and_args(short_head)
  end

  defp name_and_args(short_head) do
    Macro.decompose_call(short_head)
  end
end
```
Let's try it out:

```elixir
iex(1)> defmodule Tracer do ... end

iex(2)> defmodule Test do
          import Tracer

          deftraceable my_fun(a,b) when a<b do
            a/b
          end

          deftraceable my_fun(a,b) do
            a/b
          end
        end

iex(3)> Test.my_fun(5,10)
iex(line 4) Test.my_fun(5,10) = 0.5
0.5

iex(4)> Test.my_fun(10, 5)
iex(line 7) Test.my_fun(10,5) = 2.0
```
The main point of this exercise was to illustrate that it's possible to deduce something from the input AST. In this example, we managed to detect and handle a function guard. Obviously, the code becomes more involved, since it relies on the internal structure of the AST. In this case, the code is relatively simple, but as you'll see in [future articles](macros_5), where I'll tackle remaining problems of `deftraceable`, things can quickly become messy.
