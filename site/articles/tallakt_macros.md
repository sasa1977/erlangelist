## Author: Tallak Tveide

_Today I have a pleasure of hosting a post by [Tallak Tveide](https://twitter.com/tallakt), who dived into Elixir macros, came back alive, and decided to share his experience with us. This is his story._

In this blog post we will cover optimizing an existing function for certain known inputs, using macros. The function that we are going to optimize is 2D matrix rotation. The problem was chosen for it's simplicity. When I first used these techniques there were a few extra complexities that have been left out, please keep this in mind if the code seems like overkill.

If you are unfamiliar with macros, this blog post may be difficult to read. In that case one tip is to read [Saša Jurić's articles about Elixir macros](macros_1) first, then revisit this post.

## Two dimensional vector rotation
We want to take a vector `{x, y}` and apply any number of translate and rotate transforms on it. We want to end up with code looking like:

```elixir
transformed_point =
  {10.0, 10.0}
  |> rotate(90.0)
  |> translate(1.0, 1.0)
```
The `translate` function would simply look something like this:

```elixir
defmodule TwoD do
  def translate({x, y}, dx, dy) do
    {x + dx, y + dy}
  end
end
```
And then the `rotate` function might look like:

```elixir
defmodule TwoD do
  @deg_to_rad 180.0 * :math.pi

  def rotate({x, y}, angle) do
    radians = angle * @deg_to_rad
    { x * :math.cos(radians) - y * :math.sin(radians),
      x * :math.sin(radians) + y * :math.cos(radians) }
  end
end
```
The first subtle macro magic is already happening at this point. We are precalculating the module attribute `@deg_to_rad` at compile time to avoid calling `:math.pi` and performing a division at runtime.

I have left out `translate` from here on for clarity.

## The idea
When I first started to look at these transforms, most of my rotations were in multiples of 90 degrees. For these operations, `:math.sin(x)` and `math.cos(x)` will return the values `-1.0`, `0.0` or `1.0`, and the rotate function is reduced to reordering and changing signs of the vector tuple values in `{x, y}`.

If we spelled the code out, it would look something like this:

```elixir
defmodule TwoD do
  def rotate({x, y}, 90.0), do: {-y, x}
  def rotate({x, y}, 180.0), do: {-x, -y}
  # ... more optimized versions here

  # failing an optimized match, use the generic rotate
  def rotate({x, y}, angle) do
    radians = angle * @deg_to_rad
    { x * :math.cos(radians) - y * :math.sin(radians),
      x * :math.sin(radians) + y * :math.cos(radians) }
  end
end
```
For this particular problem, the code above, without macros, is most readable, maintainable and is also as efficient as any other code.


## The first attempt
There are basically just four variants at `[0, 90, 180, 270]` degrees that are interesting to us as `sin` and `cos` are cyclic. Our initial approach will select one of these four variants based on a parameter, and then inject some code into the `TwoD` module:

```elixir
  defmodule TwoD.Helpers do
    @deg_to_rad 180.0 * :math.pi

    def rotate({x, y}, angle) do
      radians = angle * @deg_to_rad
      { x * :math.cos(radians) - y * :math.sin(radians),
        x * :math.sin(radians) + y * :math.cos(radians) }
    end

    defmacro def_optimized_rotate(angle_quoted) do
      # angle is still code, so it must be evaluated to get a number
      {angle, _} = Code.eval_quoted(angle_quoted)

      x_quoted = Macro.var(:x, __MODULE__)
      y_quoted = Macro.var(:y, __MODULE__)
      neg_x_quoted = quote do: (-unquote(Macro.var(:x, __MODULE__)))
      neg_y_quoted = quote do: (-unquote(Macro.var(:y, __MODULE__)))

      # normalize to 0..360; must add 360 in case of negative angle values
      normalized = angle |> round |> rem(360) |> Kernel.+(360) |> rem(360)

      result_vars_quoted = case normalized do
        0 ->
          [x_quoted, y_quoted]
        90 ->
          [neg_y_quoted, x_quoted]
        180 ->
          [neg_x_quoted, neg_y_quoted]
        270 ->
          [y_quoted, neg_x_quoted]
        _ ->
          raise "Optimized angles must be right or straight"
      end

      # at last return a quoted function definition
      quote do
        def rotate({x, y}, unquote(angle * 1.0)) do
          {unquote_splicing(result_vars_quoted)}
        end
      end
    end
  end

  defmodule TwoD do
    require TwoD.Helpers

    # Optimized versions of the code
    TwoD.Helpers.def_optimized_rotate(-270)
    TwoD.Helpers.def_optimized_rotate(-180)
    TwoD.Helpers.def_optimized_rotate(-90)
    TwoD.Helpers.def_optimized_rotate(0)
    TwoD.Helpers.def_optimized_rotate(90)
    TwoD.Helpers.def_optimized_rotate(180)
    TwoD.Helpers.def_optimized_rotate(270)

    def rotate(point, angle), do: TwoD.Helpers.rotate(point, angle)
  end
```
The `rotate` function has been moved to the `TwoD.Helpers` module, and then replaced with a simple forwarding call. It will be useful when we later want to test our optimized function towards the unoptimized one.

When I first implemented `def_optimized_rotate` I was caught a bit off guard as the parameters to the macro are not available as the simple numbers that I passed them. The parameter `angle_quoted` is actually passed as a block of code.  So in order for the macro to be able to precalculate the code, we have to add `{angle, _} = Code.eval_quoted angle_quoted` at the top of our macro to expand the code for the number into an actual value.

Please note that I would not recommend using `Code.eval_quoted` for reasons that will hopefully become clear later.

For this particular problem, I am quite happy spelling out all the seven values that I want to optimize. But if there were many more interesting optimizations (for instance if the rotation was in 3D), spelling all of these out is not a good option. Let's wrap the macro call in a `for` comprehension instead.

## Inserting dynamic module definitions
Before writing the for comprehension, let's look at how a function may be defined dynamically. We'll start by making a function that simply returns it's name, but that name is assigned to a variable at compile time, before the function is defined:

```elixir
defmodule Test do
  function_name = "my_test_function"

  def unquote(function_name |> String.to_atom)() do
    unquote(function_name)
  end
end
```
And when run it in IEx, we get:

```elixir
iex(2)> Test.my_test_function
"my_test_function"
```
The thing to note is that when we are defining a module, we are in a way already inside an implicit `quote` statement, and that we may use `unquote` to expand dynamic code into our module. The first `unquote` inserts an atom containing the function name, the second inserts the return value.

Actually, I have yet to see `unquote` used like this in a module definition. Normally you would prefer to use module attributes as often as possible, as they will automatically `unquote` their values. On the other hand, it seems `unquote` offers a bit more flexibility.

```elixir
defmodule Test do
  @function_name "my_test_function"

  def unquote(@function_name |> String.to_atom)() do
    @function_name
  end
end
```
Our next step is to let the for comprehension enumerate all the angles that we want to optimize. Our `TwoD` module now looks like this:

```elixir
defmodule TwoD do
  require TwoD.Helpers

  @angles for n <- -360..360, rem(n, 90) == 0, do: n

  # Optimized versions of the code
  for angle <- @angles, do: TwoD.Helpers.def_optimized_rotate(angle)

  # This general purpose implementation will serve any other angle
  def rotate(point, angle), do: TwoD.Helpers.rotate(point, angle)
end
```
This introduces a new problem to our code. Our macro `def_optimized_rotate` now receives the quoted reference to `angle` which is not possible to evaluate in the macro context. Actually our first implementation implicitly required that the `angle` parameter be spelled out as a number. It seems wrong that the user of our macro has to know that the parameter must have a particular form.

This is the first time we will see a pattern with macro programming, and one reason to be wary of using macros: The macro might work well in one instance, but changes made in code outside of the macro could easily break it. To paraphrase a saying: The code is far from easy to reason about.

## Delaying the macro logic
_If the mountain will not come to Muhammad, Muhammad must go to the mountain._

There are two ways to use the angle values from the `for` comprehension in our macro:

- move the `for` comprehension into our macro, thus hardcoding the optimized angles
- inject everything into the resulting module definition

We'll choose the latter option beacuse I think it is more clear that the
optimized angles are stated in the `TwoD` module rather than in the macro.

There is no way to evaluate the code in the macro parameter correctly inside the macro. Instead we must move all the code into a context where the parameter may be evaluated correctly.

```elixir
defmodule TwoD.Helpers do
  @deg_to_rad :math.pi / 180.0

  def rotate({x, y}, angle) do
    radians = angle * @deg_to_rad
    { x * :math.cos(radians) - y * :math.sin(radians),
      x * :math.sin(radians) + y * :math.cos(radians) }
  end

  defmacro def_optimized_rotate(angle) do
    quote(bind_quoted: [angle_copy: angle], unquote: false) do
      x_quoted = Macro.var(:x, __MODULE__)
      y_quoted = Macro.var(:y, __MODULE__)
      neg_x_quoted = quote do: (-unquote(Macro.var(:x, __MODULE__)))
      neg_y_quoted = quote do: (-unquote(Macro.var(:y, __MODULE__)))

      # normalize to 0..360; must add 360 in case of negative angle values
      normalized = angle_copy |> round |> rem(360) |> Kernel.+(360) |> rem(360)

      result_vars_quoted = case normalized do
        0 ->
          [x_quoted, y_quoted]
        90 ->
          [neg_y_quoted, x_quoted]
        180 ->
          [neg_x_quoted, neg_y_quoted]
        270 ->
          [y_quoted, neg_x_quoted]
        _ ->
          raise "Optimized angles must be right or straight"
      end

      def rotate({unquote_splicing([x_quoted, y_quoted])}, unquote(1.0 * angle_copy)) do
        {unquote_splicing(result_vars_quoted)}
      end
    end
  end
end
```
Compared to the initial `rotate` function, this code is admittedly quite dense. This is where I gradually realize why everyone warns against macro overuse.

The first thing to note is that all the generated code is contained inside a giant quote statement. Because we want to insert `unquote` calls into our result (to be evaluated inside the module definition), we have to use the option `unquote: false`.

We may no longer use `unquote` to insert the `angle` parameter quoted. To mend this, we add the option `bind_quoted: [angle_copy: angle]`. The result of adding the `bind_quoted` option is best shown with an example:

```elixir
iex(1)> angle = quote do: 90 * 4.0
{:*, [context: Elixir, import: Kernel], [90, 4.0]}

iex(2)> Macro.to_string(quote(bind_quoted: [angle_copy: angle]) do
...(2)> rot_x = TwoD.Helpers.prepare_observed_vector {1, 0}, angle_copy, :x
...(2)> # more code
...(2)> end) |> IO.puts
(
  angle_copy = 90 * 4.0
  rot_x = TwoD.Helpers.prepare_observed_vector({1, 0}, angle_copy, :x)
)
:ok
```
`bind_quoted` is really quite simple. It just adds an assignment before any other code. This also has the benefit of ensuring that the parameter code is only evaluated once. Seems we should be using `bind_quoted` rather than inline unquoting in most circumstances.

As we don't really use the angle in the macro anymore, we no longer need `Code.eval_quoted`. I admit using it was a bad idea in the first place.

This is the second time the macro stopped working due to changes in the calling code. It seems the first version of out macro worked more or less by accident. The code:

```elixir
def rotate({x, y}, unquote(angle_copy)) do
  {unquote_splicing(result_vars_quoted)}
end
```
had to be replaced with:

```elixir
def rotate({unquote_splicing([x_quoted, y_quoted])}, unquote(angle_copy)) do
  {unquote_splicing(result_vars_quoted)}
end
```
The reason for this being that the quoted code for the result did not, due to macro hygiene, map directly to `{x,y}`.

This does the trick, and the code now works as intended.

## Testing
To test the code, we will compare the output of our optimized function and the generic implementation. The test might look like this:

```elixir
# in file test/two_d_test.exs
defmodule TwoD.Tests do
  use ExUnit.Case, async: true
  alias TwoD.Helpers, as: H

  @point {123.0, 456.0}

  def round_point({x, y}), do: {round(x), round(y)}

  test "optimized rotates must match generic version" do
    assert (TwoD.rotate(@point, -270.0) |> round_point) ==
      (H.rotate(@point, -270.0) |> round_point)

    assert (TwoD.rotate(@point, 0.0) |> round_point) ==
      (H.rotate(@point, 0.0) |> round_point)

    assert (TwoD.rotate(@point, 90.0) |> round_point) ==
      (H.rotate(@point, 90.0) |> round_point)
  end

  test "the non right/straight angles should still work" do
    assert (TwoD.rotate(@point, 85.0) |> round_point) ==
      (H.rotate(@point, 85.0) |> round_point)
  end
end
```
## Benchmarking the results
A final difficulty remains: we are still not sure whether our optimized code is actually running, or the generic implementation is still handling all function calls.

If the optimization is working, a benchmark should show us that. In any event it is useful to measure that the optimization is worthwhile. I decided to use the `benchwarmer` package for this. The `mix.exs` file is modified to include:

```elixir
  defp deps do
    [
      { :benchwarmer, "~> 0.0.2" }
    ]
  end
```
And then we'll add a simple benchmark script like this:

```elixir
# in file lib/mix/tasks/benchmark.ex
defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  def run(_) do
    IO.puts "Checking optimized vs unoptimized"
    Benchwarmer.benchmark(
      [&TwoD.Helpers.rotate/2, &TwoD.rotate/2], [{123.0, 456.0}, 180.0]
    )

    IO.puts "Checking overhead of having optimizations"
    Benchwarmer.benchmark(
      [&TwoD.Helpers.rotate/2, &TwoD.rotate/2], [{123.0, 456.0}, 182.0]
    )
  end
end
```
in turn giving us:

```
$ mix benchmark
Checking optimized vs unoptimized
*** &TwoD.Helpers.rotate/2 ***
1.6 sec   524K iterations   3.18 μs/op

*** &TwoD.rotate/2 ***
1.4 sec     2M iterations   0.71 μs/op

Checking overhead of having optimizations
*** &TwoD.Helpers.rotate/2 ***
1.3 sec     1M iterations   1.34 μs/op

*** &TwoD.rotate/2 ***
1.8 sec     1M iterations   1.78 μs/op
```
I find it a bit interesting that we are getting a 4X speedup for the straight and right angles, while at the same time the general purpose call is 20% slower. Neither of these results should come as a big surprise.

In conclusion, this technique is worthwhile if you have a slow computation that is mostly called with a specific range of arguments. It also seems wise to factor in the loss of readability.

You may browse the complete source code at [GitHub](https://github.com/tallakt/two_d)

## Thanks
Thanks to [@mgwidmann](https://twitter.com/mgwidmann) for pointing out that `unquote` is so useful inside a module definition.

Thanks to Saša Jurić for getting me through difficult compiler issues, and then helping me out with the code examples and text.