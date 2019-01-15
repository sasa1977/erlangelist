It's been about a year since I've started using Elixir. Originally, I intended to use the language only for blogging purposes, thinking it could help me better illustrate benefits of Erlang Virtual Machine (EVM). However, I was immediately fascinated with what the language brings to the table, and very quickly introduced it to the Erlang based production system I have been developing at the time. Today, I consider Elixir as a better alternative for the development of EVM powered systems, and in this posts I'll try to highlight some of its benefits, and also dispell some misconceptions about it.


## The problems of Erlang the language

EVM has many benefits that makes it easier to build highly-available, scalable, fault-tolerant, distributed systems. There are various testimonials on the Internet, and I've blogged a bit about some advantages of Erlang [here](http://theerlangelist.com/2012/12/yet-another-introduction-to-erlang.html) and [here](http://www.theerlangelist.com/2013/01/erlang-based-server-systems.html), and the chapter 1 of my upcoming book [Elixir in Action](https://www.manning.com/books/elixir-in-action-second-edition?a_aid=sjuric) presents benefits of both Erlang and Elixir.

Long story short, Erlang provides excellent abstractions for managing highly-scalable, fault-tolerant systems, which is particularly useful in concurrent systems, where many independent or loosely-dependent tasks must be performed. I've been using Erlang in production for more than three years, to build a long-polling based HTTP push server that in peak time serves over 2000 reqs/sec (non-cached). Never before have I written anything of this scale nor have I ever developed something this stable. The service just runs happily, without me thinking about it. This was actually my first Erlang code, bloated with anti-patterns, and bad approaches. And still, EVM proved to be very resilient, and run the code as best as it could. Most importantly, it was fairly straightforward for me to work on the complex problem, mostly owing to Erlang concurrency mechanism.

However, despite some great properties, I never was (and I'm still not) quite comfortable programming in Erlang. The coding experience somehow never felt very fluent, and the resulting code was always burdened with excessive boilerplate and duplication. __The problem was not the language syntax__. I did a little Prolog back in my student days, and I liked the language a lot. By extension, I also like Erlang syntax, and actually think it is in many ways nicer and more elegant than Elixir. And this is coming from an OO developer who spent most of his coding time in languages such as Ruby, JavaScript, C# and C++.

The problem I have with Erlang is that the language is somehow too simple, making it very hard to eliminate boilerplate and structural duplication. Conversely, the resulting code gets a bit messy, being harder to write, analyze, and modify. After coding in Erlang for some time, I thought that functional programming is inferior to OO, when it comes to efficient code organization.


## What Elixir is (not)

This is where Elixir changed my opinion. After I've spent enough time with the language, I was finally able to see benefits and elegance of functional programming more clearly. Now I can't say anymore that I prefer OO to FP. I find the coding experience in Elixir much more pleasant, and I'm able to concentrate on the problem I'm solving, instead of dealing with the language's shortcomings.

Before discussing some benefits of Elixir, there is an important thing I'd like to stress: __Elixir is not Ruby for Erlang__. It is also not CoffeeScript, Clojure, C++ or something else for Erlang. Relationship between Elixir and Erlang is unique, with Elixir being often semantically very close to Erlang, but in addition bringing many ideas from different languages. The end result may on surface look like Ruby, but I find it much more closer to Erlang, with both languages completely sharing the type system, and taking the same functional route.

So what is Elixir? To me, it is an Erlang-like language with improved code organization capabilities. This definition differs from what you'll see on the official page, but I think it captures the essence of Elixir, when compared to Erlang.

Let me elaborate on this. In my opinion, a programming language has a couple of roles:

- It serves as an interface that allows programmers to control something, e.g. a piece of hardware, a virtual machine, a running application, UI layout, ...
- It shapes the way developers think about the world they're modeling. An OO language will make us look for entities with state and behavior, while in FP language we'll think about data and transformations. A declarative programming language will force us to think about rules, while in imperative language we'll think more about sequence of actions.
- It provides tools to organize the code, remove duplications, boilerplate, noise, and hopefully model the problem as closely as possible to the way we understand it.

Erlang and Elixir are completely identical in first two roles - they target the same "thing" (EVM), and they both take a functional approach. It is in role three where Elixir improves on Erlang, and gives us additional tools to organize our code, and hopefully be more efficient in writing production-ready, maintainable code.


## Ingredients

Much has been said about Elixir on the Internet, but I especially like two articles from Devin Torres which you can find [here](https://devinus.io/the-excitement-of-elixir/) and [here](https://devinus.io/elixir-its-not-about-syntax/). Devin is an experienced Erlang developer, who among other things wrote a popular [poolboy](https://github.com/devinus/poolboy) library, so it's worth reading what he thinks about Elixir.

I'll try not to repeat much, and avoid going into many mechanical details. Instead, let's do a brief tour of main tools that can be used for better code organization.


### Metaprogramming

Metaprogramming in Elixir comes in a couple of flavors, but the essence is the same. It allows us to write concise constructs that seems as if they're a part of the language. These constructs are in compile-time then transformed into a proper code. On a mechanical level, it helps us remove structural duplication - a case where two pieces of code share the same abstract pattern, but they differ in many mechanical details.

For example, a following snippet presents a sketch of a module models a `User` record:

```elixir
defmodule User do
  #initializer
  def new(data) do ... end

  # getters
  def name(user) do ... end
  def age(user) do ... end

  # setters
  def name(value, user) do ... end
  def age(value, user) do ... end
end
```

Some other type of record will follow this pattern, but contain different fields. Instead of copy-pasting this pattern, we can use Elixir `defrecord` macro:

```elixir
defrecord User, name: nil, age: 0
```

Based on the given definition, `defrecord` generates a dedicated module that contains utility functions for manipulating our `User` record. Thus, the common pattern is stated only in one place (the code of `defrecord` macro), while the particular logic is relieved of mechanical implementation details.

Elixir macros are nothing like C/C++ macros. Instead of working on strings, they are something like compile-time Elixir functions that are called in the middle of parsing, and work on the abstract syntax tree (AST), which is a code represented as Elixir data structure. Macro can work on AST, and spit out some alternative AST that represents the generated code. Consequently, macros are executed in compile-time, so once we come to runtime, the performance is not affected, and there are no surprise situations where some piece of code can change the definition of a module (which is possible for example in JavaScript or Ruby).

Owing to macros, most of Elixir, is actually implemented in Elixir, including constructs such as `if`, `unless`, or unit testing support. Unicode support works by reading UnicodeData.txt file, and generating the corresponding implementation of Unicode aware string function such as `downcase` or `upcase`. This in turn makes it easier for developers to contribute to Elixir.

Macros also allow 3rd party library authors to provide internal DSLs that naturally fit in language. [Ecto](https://github.com/elixir-lang/ecto) project, that provides embedded integrated queries, something like LINQ for Elixir, is my personal favorite that really showcases the power of macros.

I've seen people sometimes dismissing Elixir, stating they don't need metaprogramming capabilities. While extremely useful, metaprogramming can also become very dangerous tool, and it is advised to carefully consider their usage. That said, there are many features that are powered by metaprogramming, and even if you don't write macros yourself, you'll still probably enjoy many of these features, such as aforementioned records, Unicode support, or integrated query language.


### Pipeline operator

This seemingly simple operator is so useful, I "invented" its [Erlang equivalent](https://github.com/sasa1977/fun_chain) even before I was aware it exists in Elixir (or other languages for that matter).

Let's see the problem first. In Erlang, there is no pipeline operator, and furthermore, we can't reassign variables. Therefore, typical Erlang code will often be written with following pattern:

```erlang
State1 = trans_1(State),
State2 = trans_2(State1),
State3 = trans_3(State2),
...
```

This is a very clumsy code that relies on intermediate variables, and correct passing of the last result to the next call. I actually had a nasty bug because I accidentally used `State6` in one place instead of `State7`.

Of course, we can go around by inlining function calls:

```erlang
trans_3(
  trans_2(
    trans_1(State)
  )
)
```

As you can see, this code can soon get ugly, and the problem is often aggravated when transformation functions receive additional arguments, and the number of transformation increases.

The pipeline operator makes it possible to combine various operations without using intermediate variables:

```elixir
state
|> trans_1
|> trans_2
|> trans_3
```

The code reads like the prose, from top to bottom, and highlights one of the strengths of FP, where we treat functions as data transformers that are combined in various ways to achieve the desired result.

For example, the following code computes the sum of squares of all positive numbers of a list:

```elixir
list
|> Enum.filter(&(&1 > 0))       # take positive numbers
|> Enum.map(&(&1 * &1))         # square each one
|> Enum.reduce(0, &(&1 + &2))   # calculate sum
```

The pipeline operator works extremely well because the API in Elixir libraries follows the "subject (noun) as the first argument" convention. Unlike Erlang, Elixir takes the stance that all functions should take the thing they operate on as the first argument. So `String` module functions take string as the first argument, while `Enum` module functions take enumerable as the first argument.

### Polymorphism via protocols

Protocols are the Elixir way of providing something roughly similar to OO interfaces. Initially, I wasn't much impressed with them, but as the time progressed, I started seeing many benefits they bring. Protocols allow developers to create a generic logic that can be used with any type of data, assuming that some contract is implemented for the given data.

An excellent example is the [Enum](http://elixir-lang.org/docs/stable/Enum.html) module, that provides many useful functions for manipulating with anything that is enumerable. For example, this is how we iterate an enumerable:

```elixir
Enum.each(enumerable, fn -> ... end)
```

`Enum.each` works with different types such as lists, or key-value dictionaries, and of course we can add support for our own types by implementing corresponding protocol. This is resemblant of OO interfaces, with an additional twist that it's possible to implement a protocol for a type, even if you don't own its source code.

One of the best example of protocol usefulness is the [Stream](http://elixir-lang.org/docs/stable/Stream.html) module, which implements a lazy, composable, enumerable abstraction. A stream makes it possible to compose various enumerable transformations, and then generate the result only when needed, by feeding the stream to some function from the `Enum` module. For example, here's the code that computes the sum of squares of all positive numbers of a list in a single pass:

```elixir
list
|> Stream.filter(&(&1 > 0))
|> Stream.map(&(&1 * &1))
|> Enum.reduce(0, &(&1 + &2))   # Entire iteration happens here in a single pass
```

In lines 2 and 3, operations are composed, but not yet executed. The result is a specification descriptor that implements an `Enumerable` protocol. Once we feed this descriptor to some `Enum` function (line 3), it starts producing values. Other than supporting protocol mechanism, there is no special laziness support from Elixir compiler.


### The mix tool

The final important piece of puzzle is the tool that help us manage projects. Elixir comes bundled with the `mix` tool that does exactly that. This is again done in an impressively simple manner. When you create a new project, only 7 files are created (including .gitignore and README.md) on the disk. And this is all it takes to create a proper OTP application. It's an excellent example of how far can things be simplified, by hiding necessary boilerplate and bureaucracy in the generic abstraction.

Mix tool supports various other tasks, such as dependency management. The tool is also extensible, so you can create your own specific tasks as needed.


### Syntactical changes

The list doesn't stop here, and there are many other benefits Elixir gives us. Many of these do include syntactical changes from Erlang, such as support for variable rebinding, optional parentheses, implicit statement endings, nullability, short circuits operators, ...

Admittedly, some ambiguity is introduced due to optional parentheses, as illustrated in this example:

```elixir
abs -1 + 5    # same as abs(-1 + 5)
```

However, I use parentheses (except for macros and zero arg functions), so I can't remember experiencing this problem in practice.

In general, I like many of the decision made in this department. It's nice to be able to write `if` without obligatory `else`. It's also nice that I don't have to consciously think which character must I use to end the statement.

Even optional parentheses are good, as they support DSL-ish usage of macros, making the code less noisy. Without them, we would have to add parentheses when invoking macros:

```elixir
defrecord User, name: nil, age: 0       # without parentheses

defrecord(User, [name: nil, age: 0])    # with parentheses
```

Still, I don't find these enhancements to be of crucial importance. They are nice finishing touches, but if this was all Elixir had to offer, I'd probably still use pure Erlang.


## Wrapping up

Much has been said in this article, and yet I feel that the magic of Elixir is far from being completely captured. The language preference is admittedly something subjective, but I feel that Elixir really improves on Erlang foundations. With more than three years of production level coding in Erlang, and about a year of using Elixir, I simply find Elixir experience to be much more pleasant. The resulting code seems more compact, and I can be more focused on the problem I'm solving, instead of wrestling with excessive noise and boilerplate.

It is for similar reasons that I like EVM. The underlying concurrency mechanisms makes it radically easier for me to tackle complexity of a highly loaded server-side system that must constantly provide service and perform many simultaneous tasks.

Both Elixir and EVM raise the abstraction bar, and help me tackle complex problems with greater ease. This is why I would always put my money behind Elixir/EVM combination as the tools of choice for building a server-side system. YMMV of course.
