Recently I came across two great articles on the Pusher blog: [Low latency, large working set, and GHC’s garbage collector: pick two of three](https://blog.pusher.com/latency-working-set-ghc-gc-pick-two/) and [Golang’s Real-time GC in Theory and Practice](https://blog.pusher.com/golangs-real-time-gc-in-theory-and-practice/). The articles tell the story of how Pusher engineers reimplemented their message bus. The first take was done in Haskell. During performance tests they noticed some high latencies in the 99 percentile range. After they bared down the code they were able to prove that these spikes are caused by the GHC stop-the-world garbage collector coupled with a large working set (the number of in-memory objects). The team then experimented with Go and got much better results, owing to Go's concurrent garbage collector.

I highly recommend both articles. The Pusher test is a great benching example, as it is focused on solving a real challenge, and evaluating a technology based on whether it's suitable for the job. This is the kind of evaluation I prefer. Instead of comparing technologies through some shallow synthetic benchmarks, such as passing a token through the ring, or benching a web server which returns "200 OK", I find it much more useful to make a simple implementation of the critical functionality, and then see how it behaves under the desired load. This should provide the answer to the question "Can I solve X efficiently using Y?". This is the approach I took when I first evaluated Erlang. A 12 hours test of the simulation of the real system with 10 times of the expected load convinced me that the technology is more than capable for what I needed.

## Challenge accepted

Reading the Pusher articles made me wonder how well would the Elixir implementation perform. After all, the underlying Erlang VM (BEAM) has been built with low and predictable latency in mind, so coupled with other properties such as fault-tolerance, massive concurrency, scalability, support for distributed systems, it seems like a compelling choice for the job.

So let me define the challenge, based on the original articles. I'll implement a FIFO buffer that can handle two operations: _push_, and _pull_. The buffer is bound by some maximum size. If the buffer is full, a push operation will overwrite the oldest item in the queue.

The goal is to reduce the maximum latency of push and pull operations of a very large buffer (max 200k items). It's important to keep this final goal in mind. I care about smoothing out latency spikes of buffer operations. I care less about which language gives me better worst-case GC pauses. While the root issue of the Pusher challenge is caused by long GC pauses, that doesn't mean that I can solve it only by moving to another language. As I'll demonstrate, relying on a few tricks in Elixir/Erlang, we can bypass GC completely and bring max latency into the microseconds area.

## Measuring

To measure the performance, I decided to run the buffer in a separate `GenServer` powered process. You can see the implementation [here](https://github.com/sasa1977/erlangelist/blob/master/examples/buffer/lib/buffer/server.ex).

The measurements are taken using Erlang's tracing capabilities. A separate process is started, which sets up the trace of the buffer process. It receives start/finish times of push and pull operations as well as buffer's garbage collections. It collects those times, and when asked, produces the final stats. You can find the implementation [here](https://github.com/sasa1977/erlangelist/blob/master/examples/buffer/lib/buffer_tracer.ex).

Tracing will cause some slowdowns. The whole bench seems to take about 2x longer when the tracing is used. I can't say how much does it affect the reported times, but I don't care that much. If I'm able to get good results with tracing turned on, then the implementation should suffice when the tracing is turned off :-)

For those of you not familiar with Erlang, the word process here refers to an Erlang process - a lightweight concurrent program that runs in the same OS process and shares nothing with other Erlang processes. At the OS level, we still have just one OS process, but inside it multiple Erlang processes are running separately.

These processes have nothing in common, share no memory and can only communicate by sending themselves messages. In particular, each process has its own separate heap, and is garbage collected separately to other processes. Therefore, whatever data is allocated by the tracer process code will not put any GC pressure on the buffer. Only the data we're actually pushing to the buffer will be considered during buffer's GC, and can thus affect the latency of buffer operations. This approach demonstrates a great benefit of Erlang. By running different things in separate processes, we can prevent GC pressure in one process to affect others in the system. I'm not aware of any other lightweight concurrency platform which provides such guarantees.

The test first starts with a brief "stretch" warmup. I create the buffer with the maximum capacity of 200k items (the number used in the Pusher benches). Then, I push 200k items, then pull all of them, and then again push 200k items. At the end of the warmup, the buffer is at its maximum capacity.

Then the bench starts. I'm issuing 2,000,000 requests in cycles of 15 pushes followed by 5 pulls. The buffer therefore mostly operates in the "overflow" mode. In total, 1,000,000 pushes are performed on the full buffer, with further 500,000 pushes on a nearly full buffer. The items being pushed are 1024 bytes Erlang binares, and each item is different from others, meaning the test will create 1,500,000 different items.

The bench code resides [here](https://github.com/sasa1977/erlangelist/blob/master/examples/buffer/lib/mix/tasks/buffer_prof.ex). The full project is available [here](https://github.com/sasa1977/erlangelist/tree/master/examples/buffer). I've benched it using Erlang 19.1 and Elixir 1.3.4, which I installed with the [asdf](https://github.com/asdf-vm/asdf) version manager. The tests are performed on my 2011 iMac (3,4 GHz Intel Core i7).

## Functional implementation

First, I'll try with what I consider an idiomatic approach in Elixir and Erlang - a purely functional implementation, based on the [:queue](http://erlang.org/doc/man/queue.html) module. According to docs, this module implements a double-ended FIFO queue in an efficient manner with most operations having an amortized O(1) running time. The API of the module provides most of the things needed. I can use `:queue.in/2` and `:queue.out/2` to push/pull items. There is no direct support for setting the maximum size, but it's fairly simple to implement this on top of the `:queue` module. You can find my implementation [here](https://github.com/sasa1977/erlangelist/blob/master/examples/buffer/lib/buffer/queue.ex).

When I originally read the Pusher articles, I was pretty certain that such implementation will lead to some larger latency spikes. While there's no stop-the-world GC in Erlang, there is still stop-the-process GC. An Erlang process starts with a fairly small heap (~ 2 Kb), and if it needs to allocate more than that, then the process is GC-ed and its heap is possibly expanded. For more details on GC, I recommend [this article](https://www.erlang-solutions.com/blog/erlang-19-0-garbage-collector.html) and [this one](https://hamidreza-s.github.io/erlang garbage collection memory layout soft realtime/2015/08/24/erlang-garbage-collection-details-and-why-it-matters.html).

In our test, this means that the buffer process will pretty soon expand to some large heap which needs to accommodate 200k items. Then, as we're pushing more items and create the garbage, the GC will have a lot of work to do. Consequently, we can expect some significant GC pauses which will lead to latency spikes. Let's verify this:

```text
$ mix buffer.bench -m Buffer.Queue

push/pull (2000000 times, average: 6.9 μs)
  99%: 17 μs
  99.9%: 32 μs
  99.99%: 74 μs
  99.999%: 21695 μs
  100%: 37381 μs
  Longest 10 (μs): 27134 27154 27407 27440 27566 27928 28138 28899 33616 37381

gc (274 times, average: 8514.46 μs)
  99%: 22780 μs
  99.9%: 23612 μs
  99.99%: 23612 μs
  99.999%: 23612 μs
  100%: 23612 μs
  Longest 10 (μs): 21220 21384 21392 21516 21598 21634 21949 22233 22780 23612

Buffer process memory: 35396 KB
Total memory used: 330 MB
```

There's a lot of data here, so I'll highlight a few numbers I find most interesting.

I'll start with the average latency of buffer operations. Averages get some bad reputation these days, but I still find them a useful metric. The observed average latency of 6.9 microseconds tells me that this implementation can cope with roughly 145,000 operations/sec without lagging, even if the buffer is completely full. If I can tolerate some latency variations, and don't expect requests at a higher rate, then the `:queue` implementation should suit my needs.

Looking at the latency distributions, we can see that the max latency is ~ 37 milliseconds. That might be unacceptable, or it may be just fine, depending on the particular use case. It would be wrong to broadly extrapolate that this `:queue` powered buffer always sucks, or to proclaim that it works well for all cases. We can only interpret these numbers if we know the specifications and requirements of the particular problem at hand.

If you look closer at latency distributions of push/pull operations, you'll see that the latency grows rapidly between four and five nines, where it transitions from two digits microseconds into a two digits milliseconds area. With 2M operations, that means we experience latency spikes for less than 200 of them. Again, whether that's acceptable or not depends on constraints of the particular problem.

The printed GC stats are related only to the buffer process. We can see that 274 GCs took place in that buffer process, with high percentile latencies being in the two-digit milliseconds range. Unsurprisingly, there seems to be a strong correlation between GC times and latency spikes which start in the 4-5 nines percentile range.

Finally, notice how the buffer process heap size is 35 MB. You might expect it to be more around 200 MB, since the buffer holds 200k items, each being 1024 bytes. However, in this bench, the items are so called [refc binaries](http://erlang.org/doc/efficiency_guide/binaryhandling.html#id67990), which means they are stored on the separate heap. The buffer process heap holds only references to these binaries, not the data itself.

Of course, the buffer process still has 200k live references on its heap, together with any garbage from the removed messages, and this is what causes latency spikes. So if I was just looking at worst-case GC times comparing them to other languages, Erlang wouldn't fare well, and I might wrongly conclude that it's not suitable for the job.

## ETS based implementation

However, I can work around the GC limitation with ETS tables. ETS tables come in a couple of shapes, but for this article I'll keep it simple by saying they can serve as an in-process in-memory key-value store. When it comes to semantics, ETS tables don't bring anything new to the table (no pun intended). You could implement the same functionality using plain Erlang processes and data structure.

However, ETS tables have a couple of interesting properties which can make them perform very well in some cases. First, ETS table data is stored in a separate memory space outside of the process heap. Hence, if we use ETS table to store items, the buffer process doesn't need to hold a lot of live references anymore, which should reduce its GC times. Moreover, the data in ETS tables is released immediately on removal. This means that we can completely remove GCs of a large set.

My implementation of an ETS based buffer is based on the Pusher's Go implementation. Basically, I'm using ETS table to simulate a mutable array, by storing k-v pairs of `(index, value)` into the table. I'm maintaining two indices, one determines where I'm going to push the next item, another does the same for the pull operation. Originally they both start with the value of zero. Then, each push stores a `(push_index, value)` pair to the table, and increases the push index by one. If the push index reaches the maximum buffer size, it's set to zero. Likewise, when pulling the data, I read the value associated with the `pull_index` key, and then increment the pull index. If the buffer is full, a push operation will overwrite the oldest value and increment both indices, thus making sure that the next pull operation will read from the proper location. The full implementation is available [here](https://github.com/sasa1977/erlangelist/blob/master/examples/buffer/lib/buffer/ets.ex).

Let's see how it performs:

```text
$ mix buffer.bench -m Buffer.Ets

push/pull (2000000 times, average: 6.53 μs)
  99%: 27 μs
  99.9%: 37 μs
  99.99%: 50 μs
  99.999%: 66 μs
  100%: 308 μs
  Longest 10 (μs): 76 80 83 86 86 96 106 186 233 308

gc (97062 times, average: 5.16 μs)
  99%: 10 μs
  99.9%: 20 μs
  99.99%: 30 μs
  99.999%: 44 μs
  100%: 44 μs
  Longest 10 (μs): 30 30 34 34 34 39 43 44 44 44

Buffer process memory: 30 KB
Total memory used: 312 MB
```

The average time of 6.53 microseconds is not radically better than the `:queue` powered implementation. However, the latency spikes are now much smaller. The longest observed latency is 308 microseconds, while in the five nines range, we're already in the two-digits microseconds area. In fact, out of 2,000,000 pushes, only 4 of them took longer than 100 microseconds. Not too shabby :-)

Full disclosure: these results are the best ones I got after a couple of runs. On my machine, the max latency sometimes goes slightly above 1ms, while other numbers don't change significantly. In particular, 99.999% is always below 100 μs.

Looking at GC stats, you can see a large increase in the number of GCs of the buffer process. In the `:queue` implementation, the buffer process triggered 274 GCs, while in this implementation we observe about 97,000 GCs. What's the reason for this? Keep in mind that the buffer process still manages some data in its own heap. This includes indices for next push/pull operation, as well as temporary references to items which have just been pushed/pulled. Since a lot of requests arrive to the buffer process, it's going to generate a lot of garbage. However, given that buffer items are stored in a separate heap of the ETS table, the buffer will never maintain a large live set. This corresponds to Pusher's conclusions. The GC spike problem is not related to the amount of generated garbage, but rather to the amount of live working set. In this implementation we reduced that set, keeping the buffer process heap pretty small. Consequently, although we'll trigger a lot of GCs, these will be pretty short. The longest observed GC of the buffer process took only 44 microseconds.

## Final thoughts

Given Erlang's stop-the-process GC properties, we might sometimes experience large pauses in some processes. However, there are some options at our disposal which can help us trim down large spikes. The main trick to control these pauses is to keep the process heap small. A large active heap coupled with frequent incoming requests is going to put more pressure on the GC, and latency is going to increase.

In this particular example, using ETS helped me reduce the heap size of the buffer process. Although the number of GCs has increased dramatically, the GC pauses were pretty short keeping the overall latency stable. While Erlang is certainly not the fastest platform around, it allows me to keep my latency predictable. I build the system, fine-tune it to reach desired performance, and I can expect less surprises in production.

It's worth mentioning two other techniques that might help you reduce your GC spikes. One approach is to split the process that manages a big heap into multiple processes with smaller working sets. This will lead to fragmented GCs, and possibly remove spikes.

In some cases you can capitalize on the fact that the process memory is immediately released when the process terminates. If you need to perform a one-off job which allocates a lot of temporary memory, you can consider using [Process.spawn](https://hexdocs.pm/elixir/Process.html#spawn/2) which allows you to explicitly preallocate a larger heap when starting the process. That might completely prevent GC from happening in that process. You do your calculation, spit out the result, and finally terminate the process so all of its memory gets immediately reclaimed without ever being GC-ed.

Finally, if you can't make some critical part of your system efficient in Erlang, you can always resort to [in-process C with NIFs](http://andrealeopardi.com/posts/using-c-from-elixir-with-nifs/) or [out-process anything with ports](http://theerlangelist.com/article/outside_elixir), keeping Elixir/Erlang as your main platform and the "controller plane" of the system. Many options are on the table, which gives me a lot of confidence that I'll be able to handle any challenge I encounter, no matter how tricky it might be.
