This is the second part of the mini-series on Elixir macros. [Last time](/article/macros_1) I discussed compilation phases and Elixir AST, finishing with a basic example of the `trace` macro. Today, I'll provide a bit more details on macro mechanics.

This is going to involve repeating some of the stuff mentioned last time, but I think it's beneficial to understand how things work and how the final AST is built. If you grasp this, you can reason about your macro code with more confidence. This becomes important, since more involved macros will consist of many combined `quote`/`unquote` constructs which can at first seem intimidating.

## Calling a macro
The most important thing to be aware of is the expansion phase. This is where compiler calls various macros (and other code-generating constructs) to produce the final AST.

For example, a typical usage of the `trace` macro will look like this:

```elixir
defmodule MyModule do
  require Tracer
  ...
  def some_fun(...) do
    Tracer.trace(...)
  end
end
```
As previously explained, the compiler starts with an AST that resembles this code. This AST is then expanded to produce the final code. Consequently, in the snippet above, the call to `Tracer.trace/1` will take place in the expansion phase.

Our macro receives the input AST and must produce the output AST. The compiler will then simply replace the macro call with the AST returned from that macro. This process is incremental - a macro can return AST that will invoke some other macro (or even itself). The compiler will simply re-expand until there's nothing left to expand.

A macro call is thus our opportunity to change the meaning of the code. A typical macro will take the input AST and somehow decorate it, adding some additional code around the input.

That's exactly what we did in the `trace` macro. We took a quoted expression (e.g. `1+2`) and spit out something like:

```elixir
result = 1 + 2
Tracer.print("1 + 2", result)
result
```
To call the `trace` macro from any part of the code (including shell), you must invoke either `require Tracer` or `import Tracer`. Why is this? There are two seemingly contradicting properties of macros:

- A macro is an Elixir code
- A macro runs in expansion time, before the final bytecode is produced

How can Elixir code run before it is produced? It can't. To call a macro, the container module (the module where the macro is defined) must already be compiled.

Consequently, to run macros defined in the `Tracer` module, we must ensure that it is already compiled. In other words, we must provide some hints to the compiler about the module ordering. When we require a module, we instruct the Elixir to hold the compilation of the current module until the required module is compiled and loaded into the compiler run-time (the Erlang VM instance where compiler is running). We can only call `trace` macro when the `Tracer` module is fully compiled, and available to the compiler.

Using `import` has the same effect but it additionally lexically imports all exported functions and macros, making it possible to write `trace` instead of `Tracer.trace`.

Since macros are functions and Elixir doesn't require parentheses in function calls, we can use this syntax:

```elixir
Tracer.trace 1+2
```
This is quite possibly the most important reason why Elixir doesn't require parentheses in function calls. Remember that most language constructs are actually macros. If parentheses were obligatory, the code we'd have to write would be noisier:

```elixir
defmodule(MyModule, do:
  def(function_1, do: ...)
  def(function_2, do: ...)
)
```
## Hygiene
As hinted in the last article, macros are by default hygienic. This means that variables introduced by a macro are its own private affair that won't interfere with the rest of the code. This is why we can safely introduce the `result` variable in our `trace` macro:

```elixir
quote do
  result = unquote(expression_ast)  # result is private to this macro
  ...
end
```

This variable won't interfere with the code that is calling the macro. In place where you call the trace macro, you can freely declare your own `result` variable, and it won't be shadowed by the `result` from the tracer macro.

Most of the time hygiene is exactly what you want, but there are exceptions. Sometimes, you may need to create a variable that is available to the code calling the macro. Instead of devising some contrived example, let's take a look at the real use case from the Plug library. This is how we can specify routes with Plug router:

```elixir
get "/resource1" do
  send_resp(conn, 200, ...)
end

post "/resource2" do
  send_resp(conn, 200, ...)
end
```
Notice how in both snippets we use `conn` variable that doesn't exist. This is possible because `get` macro binds this variable in the generated code. You can imagine that the resulting code is something like:

```elixir
defp do_match("GET", "/resource1", conn) do
  ...
end

defp do_match("POST", "/resource2", conn) do
  ...
end
```
_Note: the real code produced by Plug is somewhat different, this is just a simplification._

This is an example of a macro introducing a variable that must not be hygienic. The variable `conn` is introduced by the `get` macro, but must be visible to the code where the macro is called.

Another example is the situation I had with ExActor. Take a look a the following example:

```elixir
defmodule MyServer do
  ...
  defcall my_request(...), do: reply(result)
  ...
end
```
If you're familiar with `GenServer` then you know that the result of a call must be in form `{:reply, response, state}`. However, in the snippet above, the state is not even mentioned. So how can we return the non-mentioned state? This is possible, because `defcall` macro generates a hidden state variable, which is then implicitly used by the `reply` macro.

In both cases, a macro must create a variable that is not hygienic and must be visible beyond macro's quoted code. For such purposes you can use `var!` construct. Here's how a simple version of the Plug's `get` macro could look like:

```elixir
defmacro get(route, body) do
  quote do
    defp do_match("GET", unquote(route), var!(conn)) do
      # put body AST here
    end
  end
end
```
Notice how we use `var!(conn)`. By doing this, we're specifying that `conn` is a variable that must be visible to the caller.

In the snippet above, it's not explained how the body is injected. Before doing so, you must understand a bit about arguments that macros receive.

## Macro arguments
You should always keep in mind that macros are essentially Elixir functions that are invoked in expansion phase, while the final AST is being produced. The specifics of macros is that arguments being passed are always quoted. This is why we can call:

```elixir
def my_fun do
  ...
end
```
Which is the same as:

```elixir
def(my_fun, do: (...))
```
Notice how we're calling the `def` macro, passing `my_fun` even when this variable doesn't exist. This is completely fine, since we're actually passing the result of `quote(do: my_fun)`, and quoting doesn't require that the variable exists. Internally, `def` macro will receive the quoted representation which will, among other things, contain `:my_fun`. The `def` macro will use this information to generate the function with the corresponding name.

Another thing I sort of skimmed over is the `do...end` block. Whenever you pass a `do...end` block to a macro, it is the same as passing a keywords list with a `:do` key.

So the call

```elixir
my_macro arg1, arg2 do ... end
```
is the same as

```elixir
my_macro(arg1, arg2, do: ...)
```
This is just a special syntactical sugar of Elixir. The parser transforms `do..end` into `{:do, ...}`.

Now, I've just mentioned that arguments are quoted. However, for many constants (atoms, numbers, strings), the quoted representation is exactly the same as the input value. In addition, two element tuples and lists will retain their structure when quoted. This means that `quote(do: {a,b})` will give a two element tuple, with both values being of course quoted.

Let's illustrate this in a shell:

```elixir
iex(1)> quote do :an_atom end
:an_atom

iex(2)> quote do "a string" end
"a string"

iex(3)> quote do 3.14 end
3.14

iex(4)> quote do {1,2} end
{1, 2}

iex(5)> quote do [1,2,3,4,5] end
[1, 2, 3, 4, 5]
```
In contrast, a quoted three element tuple doesn't retain its shape:

```elixir
iex(6)> quote do {1,2,3} end
{:{}, [], [1, 2, 3]}
```
Since lists and two element tuples retain their structure when quoted, the same holds for a keyword list:

```elixir
iex(7)> quote do [a: 1, b: 2] end
[a: 1, b: 2]

iex(8)> quote do [a: x, b: y] end
[a: {:x, [], Elixir}, b: {:y, [], Elixir}]
```
In the first example, you can see that the input keyword list is completely intact. The second example proves that complex members (such as references to `x` and `y`) are quoted. But the list still retains its shape. It is still a keyword lists with keys `:a` and `:b`.

## Putting it together
Why is all this important? Because in the macro code, you can easily retrieve the options from the keywords list, without analyzing some convoluted AST. Let's see this in action on our oversimplified take on `get` macro. Earlier, we left with this sketch:

```elixir
defmacro get(route, body) do
  quote do
    defp do_match("GET", unquote(route), var!(conn)) do
      # put body AST here
    end
  end
end
```
Remember that `do...end` is the same as `do: ...` so when we call `get route do ... end`, we're effectively calling `get(route, do: ...)`. Keeping in mind that macro arguments are quoted, but also knowing that quoted keyword lists keep their shape, it's possible to retrieve the quoted body in the macro using `body[:do]`:

```elixir
defmacro get(route, body) do
  quote do
    defp do_match("GET", unquote(route), var!(conn)) do
      unquote(body[:do])
    end
  end
end
```
So we simply inject the quoted input body into the body of the `do_match` clause we're generating.

As already mentioned, this is the purpose of a macro. It receives some AST fragments, and combines them together with the boilerplate code, to generate the final result. Ideally, when we do this, we don't care about the contents of the input AST. In our example, we simply inject the body in the generated function, without caring what is actually in that body.

It is reasonably simple to test that this macro works. Here's a bare minimum of the required code:

```elixir
defmodule Plug.Router do
  # get macro removes the boilerplate from the client and ensures that
  # generated code conforms to some standard required by the generic logic
  defmacro get(route, body) do
    quote do
      defp do_match("GET", unquote(route), var!(conn)) do
        unquote(body[:do])
      end
    end
  end
end
```
Now we can implement a client module:

```elixir
defmodule MyRouter do
  import Plug.Router

  # Generic code that relies on the multi-clause dispatch
  def match(type, route) do
    do_match(type, route, :dummy_connection)
  end

  # Using macro to minimize boilerplate
  get "/hello", do: {conn, "Hi!"}
  get "/goodbye", do: {conn, "Bye!"}
end
```
And test it:

```elixir
MyRouter.match("GET", "/hello") |> IO.inspect
# {:dummy_connection, "Hi!"}

MyRouter.match("GET", "/goodbye") |> IO.inspect
# {:dummy_connection, "Bye!"}
```
The important thing to notice here is the code of `match/2`. This is the generic code that relies on the existence of the implementation of `do_match/3`.

## Using modules
Looking at the code above, you can see that the glue code of `match/2` is developed in the client module. That's definitely far from perfect, since each client must provide correct implementation of this function, and be aware of how `do_match` function must be invoked.

It would be better if `Plug.Router` abstraction could provide this implementation for us. For that purpose we can reach for the `use` macro, a rough equivalent of mixins in other languages.

The general idea is as follows:

```elixir
defmodule ClientCode do
  # invokes the mixin
  use GenericCode, option_1: value_1, option_2: value_2, ...
end

defmodule GenericCode do
  # called when the module is used
  defmacro __using__(options) do
    # generates an AST that will be inserted in place of the use
    quote do
      ...
    end
  end
end
```
So the `use` mechanism allows us to inject some piece of code into the caller's context. This is just a replacement for something like:

```elixir
defmodule ClientCode do
  require GenericCode
  GenericCode.__using__(...)
end
```
Which can be proven by looking [in Elixir source code](https://github.com/elixir-lang/elixir/blob/v0.14.0/lib/elixir/lib/kernel.ex#L3531-L3532). This proves another point - that of incremental expansion. The `use` macro generates the code which will call another macro. Or to put it more fancy, `use` generates a code that generates a code. As mentioned earlier, the compiler will simply reexpand this until there's nothing left to be expanded.

Armed with this knowledge, we can move the implementation of the `match` function to the generic `Plug.Router` module:

```elixir
defmodule Plug.Router do
  defmacro __using__(_options) do
    quote do
      import Plug.Router

      def match(type, route) do
        do_match(type, route, :dummy_connection)
      end
    end
  end

  defmacro get(route, body) do
    ... # This code remains the same
  end
end
```
This now keeps the client code very lean:

```elixir
defmodule MyRouter do
  use Plug.Router

  get "/hello", do: {conn, "Hi!"}
  get "/goodbye", do: {conn, "Bye!"}
end
```
As mentioned, the AST generated by the `__using__` macro will simply be injected in place of the `use Plug.Router` call. Take special note how we do `import Plug.Router` from the `__using__` macro. This is not strictly needed, but it allows the client to call `get` instead of `Plug.Router.get`.

So what have we gained? The various boilerplate is now confined to the single place (`Plug.Router`). Not only does this simplify the client code, it also keeps the abstraction properly closed. The module `Plug.Router` ensures that whatever is generated by `get` macros fits properly with the generic code of `match`. As clients, we simply use the module and call into the provided macros to assemble our router.

This concludes today's session. Many details are not covered, but hopefully you have a better understanding of how macros integrate with the Elixir compiler. In the [next part](/article/macros_3) I'll dive deeper and start exploring how we can tear apart the input AST.