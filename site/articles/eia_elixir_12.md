[Elixir 1.2 is out](http://elixir-lang.org/blog/2016/01/03/elixir-v1-2-0-released/), and this is the second minor release since Elixir in Action has been published, so I wanted to discuss some consequences of new releases on the book's material.

Since the book focuses on concurrency and OTP principles, most of its content is still up to date. OTP is at this point pretty stable and not likely to be significantly changed. Moreover, Elixir 1.2 is mostly downwards compatible, meaning that the code written for earlier 1.x versions should compile and work on 1.2. In some cases, some minor modifications might be required, in which case the compiler should emit a corresponding error/warning.

 All that said, some information in the book is not completely accurate anymore, so I'd like to point out a few things.

## Updated code examples

Some minor changes had to be made to make the code examples work, most notably [relaxing the versioning requirement in mix.exs](https://github.com/sasa1977/elixir-in-action/commit/05b6fb3a73db893727a5b9b43da4087af878f058). You can find the 1.2 compliant code examples [here](https://github.com/sasa1977/elixir-in-action/tree/Elixir-v1.2).


## Deprecating Dict and Set

Elixir 1.2 requires Erlang 18.x which brings a couple of big changes. You can see the highlights [here](http://www.erlang.org/download_release/29), but in the context of EiA, the most important improvement deals with maps which now perform well for large datasets. Consequently, `HashDict` and `HashSet` are becoming redundant.

Therefore the Elixir core team decided to deprecate following k-v and set related modules: `Dict`, `Set`, `HashDict`, and `HashSet`. These modules are __soft__ deprecated, meaning that they will in fact still work, but their usage is discouraged as they are marked for subsequent removal. If you're developing for Elixir 1.2+ you're encouraged to use plain maps for k-v structure, and the new type [MapSet](http://elixir-lang.org/docs/stable/elixir/MapSet.html) (internally also powered by maps) for sets.

There's one important caveat: if your code must work on Elixir 1.0 and 1.1, then you should in fact still prefer `HashDict` and `HashSet`. The reason is that the older Elixir version can run on Erlang 17, so if your code uses large maps, the performance might suffer.

For Elixir in Action, this means that all the code that's using `HashDict` should be changed to use maps. Most notably, the `Todo.List` abstraction should internally use maps to maintain the `entries` field. You can see the changes in [this commit](https://github.com/sasa1977/elixir-in-action/commit/51bc04bf48730bfbb6141ad781f8300cc6e91db5).


## Protocol consolidation

Starting Elixir 1.2, protocols are consolidated by default in all build environments. As a result, the subsection "Protocol Consolidation" (page 326) becomes redundant. With new Elixir you don't need to worry about consolidation.


## Embedded build and permanent applications

This change has been introduced way back in Elixir 1.0.4, and there's [a nice post by José Valim on the subject](http://blog.plataformatec.com.br/2015/04/build-embedded-and-start-permanent-in-elixir-1-0-4/).

The gist of the story is that two mix properties are introduced which allow you to configure the "embedded build" and "permanent applications". By default, new projects generated with Elixir 1.0.4+ will have these properties set to true for `prod` mix environment. If you generated your project before 1.0.4, you should add the following options to your `mix.exs` (in the `project/0`):

```elixir
def project do
  [
    # ...
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod
  ]
end
```

When the `:build_embedded` option is set to true, the target folder will not contain symlinks. Instead, all data that needs to be in that folder (e.g. the content of the `priv` folder) will be copied.

The `start_permanent` option, if set to true, will cause the OTP application to be started as permanent. If the application crashes, that is if the top-level supervisor terminates, the whole BEAM node will be terminated. This makes sense in the production, because it allows you to to detect application crash in another OS process, and do something about it.

As José explains, it's sensible to set both options to true for production environment. In contrast, you probably want to have them unset during development for convenience.


## That's all folks :-)

Yep, nothing else of the book content is affected by new changes to Elixir. However, many cool features have been introduced since Elixir 1.0, such as the [with special form](http://elixir-lang.org/docs/stable/elixir/Kernel.SpecialForms.html#with/1), or the [mix profile.fprof](http://elixir-lang.org/docs/stable/mix/Mix.Tasks.Profile.Fprof.html) task. Therefore, I suggest reading through the [changelogs of recent releases](https://github.com/elixir-lang/elixir/releases) :-)

Happy coding!
