About a month ago, on [Elixir Quiz](http://elixirquiz.github.io/index.html) site there was a [Conway's Game of Life challenge](http://elixirquiz.github.io/2014-11-01-game-of-life.html). While I didn't find the time to participate in the challenge, I played with the problem recently, and found it very interesting.

So in this post, I'm going to break down [my solution to the problem](https://gist.github.com/sasa1977/6877c52c3c35c2c03c82). If you're not familiar with Game of Life rules, you can take a quick look [here](http://en.wikipedia.org/wiki/Conway%27s_Game_of_Life#Rules).

My solution is simplified in that I deal only with square grids. It's not very hard to extend it to work for any rectangle, but I wanted to keep things simple.

## Functional abstraction
The whole game revolves around the grid of cells which are in some state (dead or alive), and there are clear rules that determine the next state of each cell based on the current state of its neighbours. Thus, I've implemented the `Conway.Grid` module that models the grid. Let's see how the module will be used.

The initial grid can be created with `Conway.Grid.new/1`:

```elixir
# Creates 5x5 grid with random values
grid = Conway.Grid.new(5)

# Creates grid from the given cell data
grid = Conway.Grid.new([
  [1, 1, 0],
  [0, 1, 0],
  [1, 1, 0]
])
```
As can be deducted from the second example, a cell state can be either zero (not alive) or one (alive).

Once the grid is instantiated, we can move it a step forward with `Conway.Grid.next/1`:

```elixir
grid = Conway.Grid.next(grid)
```
Finally, we can query grid's size, and the value of each cell:

```elixir
Conway.Grid.size(grid)

# Returns 0 or 1 for the cell at the given location
Conway.Grid.cell_status(grid, x, y)
```
This is all we need to manipulate the grid and somehow display it.

This is a simple decoupling technique. The game logic is contained in the single module, but the "driving" part of the game, i.e. the code that repeatedly moves the game forward, is left out.

This allows us to use the core game module in different contexts. In my example, I'm using `Conway.Grid` [from a simplistic terminal client](https://gist.github.com/sasa1977/6877c52c3c35c2c03c82#file-conway-ex-L100-L125), but it's easy to use the module from a `GenServer` for example to push updates to various connected clients, or from unit tests to verify that state transition works properly.

Another nice benefit of this approach is that we can use `:erlang.term_to_binary/1` to serialize the structure and persist the grid state, and then later deserialize it and resume playing the grid.

This is what I like to call a functional abstraction. Notice in previous examples how we use `Conway.Grid` without knowing its internal representation. The module abstracts away its internal details. In particular, as clients, we don't care what data type is used for the module. All we know that creator and updater functions return a "grid", and all functions from `Conway.Grid` know how to work with that grid.

The module thus abstracts some concept, and does so relying on a pure functional (immutable) data structure. Hence, a functional abstraction.

__Note__: Frequently, the term __type__ is used for this. I'm not particular fan of this terminology. To me, the only true Elixir types are [the ones supported by BEAM](http://www.erlang.org/doc/reference_manual/data_types.html). All others, such as `HashDict`, `HashSet`, `Range`, Erlang's `:gb_trees`, and even structs, are somehow composed from those basic types.

## Choosing the data representation
__Update:__ As Greg and leikind pointed out in comments, the approach I'm taking here is neither efficient nor flexible, because I'm keeping and processing all cells, instead of dealing only with live ones. You can find the alternative version, where only live cells are kept in a `HashSet` [here](https://gist.github.com/sasa1977/7d101a5698edfd6b0dc9). The nice thing is that the change was simple, due to abstraction of the `Conway.Grid`. The module interface remained the same.

In any case, let's start implementing `Conway.Grid`. The most important decision is how to represent the grid data. Given the game rules, we have following needs:

- random access to cells (their states)
- incremental building of the grid

We need the first property to access neighbour cells when determining the next state of each cell. The second property is needed since in each step we fully rebuild the grid based on the current state of each cell.

In BEAM, tuples are a good fit for random access (which is O(1) operation), but they are poor for incremental building. Modifying a tuple [(almost always) results in (shallow) copying of all tuple elements](http://www.erlang.org/doc/efficiency_guide/commoncaveats.html#id61125). This can hurt performance and increase memory usage.

In contrast, lists are crappy for random access, but they are efficient for incremental building, if we're either prepending new elements to the head, or building the list in a body-recursive way.

However, we can use different approaches in different situations. In particular, we can:

- Maintain a 2D grid as a tuple of tuples. This gives us an O(1) random access complexity.
- Build a new grid as a lists of lists. Once the new grid is built, convert it to tuple of tuples via `List.to_tuple/1`.

`List.to_tuple/1` will be efficient (though still O(n)), since it is implemented in C, and does it's job by [preallocating the tuple and populating it from the list](https://github.com/erlang/otp/blob/743ed31108ee555db18d9833186865e85e34333e/erts/emulator/beam/bif.c#L3424-L3431). Thus, we avoid extra copying of tuples.

Performance wise, this is probably not the optimal implementation, but I think it's a reasonable first attempt that still keeps the code simple and clear.

So to recap, out grid will be implemented as the tuple of tuples:

```elixir
{
  {1, 1, 0},
  {0, 1, 0},
  {1, 1, 0}
}
```
This is all the data we need, since we can efficiently derive the grid size from the data via `Kernel.tuple_size/1`. It's still worth making our `Conway.Grid` a struct, so we can gain pattern matching, possible polymorphism, and easier extensibility.

Hence, the skeleton of the module will look like:

```elixir
defmodule Conway.Grid do
  defstruct data: nil

  ...
end
```
Now we can start implementing the module.

## Constructing the grid
Recall from usage examples that our "constructor" function is overloaded. It either takes a grid dimension and creates the randomly populated grid, or it takes a list of lists with prepopulated data.

Let's solve the latter case first:

```elixir
def new(data) when is_list(data) do
  %Conway.Grid{data: list_to_data(data)}
end

defp list_to_data(data) do
  data
  |> Enum.map(&List.to_tuple/1)     # convert every inner list
  |> List.to_tuple                  # convert the outer list
end
```
Now, we can do the random population. We'll first implement a helper generic function for creating the grid data:

```elixir
defp new_data(size, producer_fun) do
  for y <- 0..(size - 1) do
    for x <- 0..(size - 1) do
      producer_fun.(x, y)
    end
  end
  |> list_to_data
end
```
Here, we take the desired size, and produce a square list of lists, calling the `producer_fun` lambda for each element. Then, we just pass it to `list_to_data/1` to convert to a tuple of tuples. This genericity of `new_data/2` will allow us to reuse the code when moving the grid to the next state.

For the moment, we can implement the second clause of `new/1`:

```elixir
def new(size) when is_integer(size) and size > 0 do
  %Conway.Grid{
    data: new_data(size, fn(_, _) -> :random.uniform(2) - 1 end)
  }
end
```

Next, let's implement two getter functions for retrieving the grid size and the state of each cell:

```elixir
def size(%Conway.Grid{data: data}), do: tuple_size(data)

def cell_status(grid, x, y) do
  grid.data
  |> elem(y)
  |> elem(x)
end
```

## Shifting the state
The only thing remaining is to move the grid to the next state. Let's start with the interface function:

```elixir
def next(grid) do
  %Conway.Grid{grid |
    data: new_data(size(grid), &next_cell_status(grid, &1, &2))
  }
end
```
As mentioned earlier, we reuse the existing `new_data/2` function. We just provide a different lambda which will generate new cell states based on the current grid state.

Implementation of `next_cell_status/3` embeds the game rules:

```elixir
def next_cell_status(grid, x, y) do
  case {cell_status(grid, x, y), alive_neighbours(grid, x, y)} do
    {1, 2} -> 1
    {1, 3} -> 1
    {0, 3} -> 1
    {_, _} -> 0
  end
end
```
Here I've resorted to a `case` branch, because I think it's the most readable approach in this case. I've experimented with moving this branching to a separate multiclause, but then it was less clear what is being pattern-matched.

## Counting alive neighbours
Now we move to the most complex part of the code. Calculating the number of alive neighbours. For this, we have to get the state of each surrounding cell, and count the number of those which are alive.

In this example, I've decided to use the `for` comprehension, because it has nice support for multiple generators and rich filters.

However, `for` emits results to a collectable, and we need a single integer (the count of alive neighbours). Therefore, [I've implemented a simple sum collectable](https://gist.github.com/sasa1977/6877c52c3c35c2c03c82#file-conway-ex-L4-L25). It allows us to collect an enumerable of numbers into an integer containing their sum.

The idea is then to use `for` to filter all alive neighbours, emit value 1 for each such neighbour, and collect those 1s into a `Sum` instance:

```elixir
defp alive_neighbours(grid, cell_x, cell_y) do
  # 1. Iterate all x,y in -1..+1 area
  for x <- (cell_x - 1)..(cell_x + 1),
      y <- (cell_y - 1)..(cell_y + 1),
      (
        # take only valid coordinates
        x in 0..(size(grid) - 1) and
        y in 0..(size(grid) - 1) and

        # don't include the current cell
        (x != cell_x or y != cell_y) and

        # take only alive cells
        cell_status(grid, x, y) == 1
      ),
      # collect to Sum
      into: %Sum{}
  do
    1   # add 1 for every alive neighbour
  end
  |> Sum.value    # get the sum value
end
```
I did initial implementation of this with nested `Enum.reduce/3` and I wasn't as pleased. This solution actually takes more LOC, but I find it easier to understand. There are many other ways of implementing this counting, but to me this approach seems pretty readable. YMMV of course.

__Update:__ Tallak Tveide rightfully asked why not just pipe the result of `for` into `Enum.sum/1` (note also that `Enum.count/1` also works). This will work, and quite possibly perform just fine. However, when I was first writing this particular function, I asked myself why would I want to create an intermediate enumerable just to count its size. This is why I made the `Sum` collectable. It's probably over-engineering / micro-optimizing for this case, but I found it an interesting exercise. As an added benefit, I have a generic `Sum` collectable which I can use in any of my code whenever I need to count the number of filtered items.

In any case, we're done. The simple implementation of Conway's Game of Life is finished. We have a nice functional abstraction and a basic terminal client. Give it a try on your machine. Just paste [the complete code](https://gist.github.com/sasa1977/6877c52c3c35c2c03c82) into the `iex` shell, or run it with `elixir conway.ex`.