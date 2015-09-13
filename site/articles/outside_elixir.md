Occasionally it might be beneficial to implement some part of the system in something other than Erlang/Elixir. I see at least two reasons for doing this. First, it might happen that a library for some particular functionality is not available, or not as mature as its counterparts in other languages, and creating a proper Elixir implementation might require a lot of effort. Another reason could be raw CPU speed, something which is not Erlang's forte, although in my personal experience that rarely matters. Still, if there are strong speed requirement in some CPU intensive part of the system, and every microsecond is important, Erlang might not suffice.

There may exist some other situations where Erlang is possibly not the best tool for the job. Still, that's not necessarily the reason to dismiss it completely. Just because it's not suitable for some features, doesn't mean it's not a good choice to power most of the system. Moreover, even if you stick with Erlang you still can resort to other languages to implement some parts of it. Erlang provides a couple of techniques to do this, but in my personal opinion the most compelling option is to start external programs from Erlang via [ports](http://erlang.org/doc/reference_manual/ports.html). This is the approach I'd consider first, and then turn to other alternatives in some special cases. So in this article, I'll talk about ports but before parting, I'll briefly mention other options and discuss some trade-offs.


## Basic theory
An Erlang port is a process-specific resource. It is owned by some process and that process is the only one that can talk to it. If the owner process terminates, the port will be closed. You can create many ports in the system, and a single process can own multiple ports. It's worth mentioning that a process can hand over the ownership of the port to another process.

An examples of ports are file handles and network sockets which are connected to the owner process and closed if that process terminates. This allows proper cleanup in an well structured OTP application. Whenever you take down some part of the supervision tree, all resources owned by terminated processes will be closed.

From the implementation standpoint, ports come in two flavors. They can either be powered by a code which runs directly in the VM itself (port driver), or they can run as an external OS process outside of the BEAM. Either way, the principles above hold and you use mostly the same set of functions exposed in the [Port module](http://elixir-lang.org/docs/stable/elixir/Port.html) - tiny wrappers around port related functions from the `:erlang` module. In this article I'll focus on ports as external processes. While not the fastest option, I believe this is often a sensible approach because it preserves fault-tolerance properties.

Before starting, I should also mention the [Porcelain](https://github.com/alco/porcelain) library, by Alexei Sholik, which can simplify working with ports in some cases. You should definitely check it out, but in this article I will just use the `Port` module to avoid the extra layer of abstraction.

## First take
Let's see a simple example. In this exercise we'll introduce the support for running Ruby code from the Erlang VM. Under the scene, we'll start a Ruby process from Erlang and send it Ruby commands. The process will eval those commands and optionally send back responses to Erlang. We'll also make the Ruby interpreter stateful, allowing Ruby commands to share the same state. Of course, it will be possible to start multiple Ruby instances and achieve isolation as well.

The initial take is simple. To run an external program via port, you need to open a port via `Port.open/2`, providing a command to start the external program. Then you can use `Port.command/2` to issue requests to the program. If the program sends something back, the owner process will receive a message. This is pretty resemblant to the classic message passing approach.

On the other side, the external program uses standard input/output to talk to its owner process. Basically, it needs to read from stdin, decode the input, do its stuff, and optionally print the response on stdout which will result in a message back to the Erlang process. When the program detects EOF on stdin, it can assume that the owner process has closed the port.

Let's see this in action. First, we'll define the command to start the external program, in this case a Ruby interpreter:

```elixir
cmd = ~S"""
  ruby -e '
    STDOUT.sync = true
    context = binding

    while (cmd = gets) do
      eval(cmd, context)
    end
  '
"""
```
This is a simple program that reads lines from stdin and evals them in the same context, thus ensuring that the side effect of the previous commands is visible to the current one. The `STDOUT.sync = true` bit ensures that whatever we output is immediately flushed, and thus sent back to the owner Erlang process.

Now we can start the port:

```elixir
port = Port.open({:spawn, cmd}, [:binary])
```
The second argument contains port options. For now, we'll just provide the `:binary` option to specify that we want to receive data from the external program as binaries. We'll use a couple of more options later on, but you're advised to read the [official documentation](http://www.erlang.org/doc/man/erlang.html#open_port-2) to learn about all the available options.

Assuming you have a Ruby interpreter somewhere in the path, the code above should start a corresponding OS process, and you can now use `Port.command/2` to talk to it:

```elixir
Port.command(port, "a = 1\n")
Port.command(port, "a += 2\n")
Port.command(port, "puts a\n")
```
This is fairly straightforward. We just send some messages to the port, inserting newlines to make sure the other side gets them (since it uses `gets` to read line by line). The Ruby program will eval these expressions (since we've written it that way). In the very last expression, we print the contents of the variable. This last statement will result in a message to the owner process. We can `receive` this message as usual:

```elixir
receive do
  {^port, {:data, result}} ->
    IO.puts("Elixir got: #{inspect result}")
end

# Elixir got: "3\n"
```
The full code is available [here](https://gist.github.com/sasa1977/36c91befb96412e244c6).

## Program termination
It's worth noting again, that a port is closed when the owner process terminates. In addition, the owner process can close the port explicitly with `Port.close/1`. When a port is closed the external program is not automatically terminated, but pipes used for communication will be closed. When the external program reads from stdin it will get EOF and can do something about it, for example terminate.

This is what we already do in our Ruby program:

```ruby
while (cmd = gets) do
  eval(cmd, context)
end
```
By stopping the loop when `gets` returns nil we ensure that the program will terminate when the port is closed.

There are a few caveats though. Notice how we eval inside the loop. If the code in `cmd` takes a long time to run, the external program might linger after the port is closed. This is simply due to the fact that the program is busy processing the current request, so it can't detect that the other side has closed the port. If you want to ensure immediate termination, you can consider doing processing in a separate thread, while keeping the main thread focused on the communication part.

Another issue is the fact that closing the port closes both pipes. This may present a problem if you want to directly use tools which produce their output only after they receive EOF. In the context of port, when this happens, both pipes are already closed, so the tool can't send anything back via stdout. There are quite a few discussion on this issue (see [here](http://erlang.org/pipermail/erlang-questions/2013-July/074905.html) for example). Essentially, you shouldn't worry about it if you implement your program to act as a server which waits for requests, does some processing, and optionally spits out the result. However, if you're trying to reuse a program which is not originally written to run as a port, you may need to wrap it in some custom script, or resort to libraries which offer some workarounds, such as the aforementioned Porcelain.

## Packing messages
The communication between the owner process and the port is by default streamed, which means there are no guarantees about message chunks, so you need to somehow parse messages yourself, character by character.

In the previous example the Ruby code relies on newlines to serve as command separators (by using `gets`). This is a quick solution, but it prevents us from running multiline commands. Moreover, when receiving messages in Elixir, we don't have any guarantees about chunking. Data is streamed back to us as it is printed, so a single message might contain multiple responses, or a single response might span multiple messages.

A simple solution for this is to include the information about the message size in the message itself. This can be done by providing the `{:packet, n}` option to `Port.open/2`:

```elixir
port = Port.open({:spawn, cmd}, [:binary, {:packet, 4}])
```
Each message sent to the port will start with `n` bytes (in this example 4) which represent the byte size of the rest of the message. The size is encoded as an unsigned big-endian integer.

The external program then needs to read this 4 bytes integer, and then get the corresponding number of bytes to obtain the message payload:

```ruby
def receive_input
  encoded_length = STDIN.read(4)                # get message size
  return nil unless encoded_length

  length = encoded_length.unpack("N").first     # convert to int
  STDIN.read(length)                            # read message
end
```
Now we can use `receive_input` in the eval loop:

```ruby
while (cmd = receive_input) do
  eval(cmd, context)
end
```
These changes allow the Elixir client to send multi-line statements:

```elixir
Port.command(port, "a = 1")
Port.command(port, ~S"""
  while a < 10 do
    a *= 3
  end
""")
```
When the Ruby program needs to send a message back to Erlang, it must also include the size of the message:

```ruby
def send_response(value)
  response = value.inspect
  STDOUT.write([response.bytesize].pack("N"))
  STDOUT.write(response)
  true
end
```
Elixir code can then use `send_response` to make the Ruby code return something. To prove that responses are properly chunked, let's send two responses:

```elixir
Port.command(port, ~S"""
  send_response("response")
  send_response(a)
""")
```
Which will result in two messages on the Elixir side:

```elixir
receive do
  {^port, {:data, result}} ->
    IO.puts("Elixir got: #{inspect result}")
end

receive do
  {^port, {:data, result}} ->
    IO.puts("Elixir got: #{inspect result}")
end

# Elixir got: "\"response\""
# Elixir got: "27"
```
The complete code is available [here](https://gist.github.com/sasa1977/9c43d54f6065ecaea992).

## Encoding/decoding messages
The examples so far use plain string as messages. In more involved scenarios you may need to deal with various data types. There's no special support for this. Essentially a process and a port exchange byte sequences, and it is up to you to implement some encoding/decoding scheme to facilitate data typing. You can resort to popular formats such as JSON for this purpose.

In this example, I'll use [Erlang's External Term Format (ETF)](http://erlang.org/doc/apps/erts/erl_ext_dist.html). You can easily encode/decode any Erlang term to ETF via `:erlang.term_to_binary/1` and `:erlang.binary_to_term/1`. A nice benefit of this is that you don't need any third party library on the Elixir side.

Let's see this in action. Instead of plain strings, we'll send `{:eval, command}` tuples to the Ruby side. The Ruby program will execute the command only if it receives `:eval` tagged tuple. In addition, when responding back, we'll again send the message as tuple in form of `{:response, value}`, where value will also be an Erlang term.

On the Elixir side we'll introduce a helper lambda to send `{:eval, command}` tuples to the port. It will simply pack the command into a tuple and encode it to ETF binary:

```elixir
send_eval = fn(port, command) ->
  Port.command(port, :erlang.term_to_binary({:eval, command}))
end
```
The function can then be used as:

```elixir
send_eval.(port, "a = 1")
send_eval.(port, ~S"""
  while a < 10 do
    a *= 3
  end
""")
send_eval.(port, "send_response(a)")
```
On the Ruby side, we need to decode ETF byte sequence. For this, we need to resort to some 3rd party library. After a quick (and very shallow) research, I opted for [erlang-etf](https://github.com/potatosalad/erlang-etf). We need to create a `Gemfile` with the following content:

```ruby
source "https://rubygems.org"

gem 'erlang-etf'
```
And then run `bundle install` to fetch gems.

Now, in our Ruby code, we can require necessary gems:

```ruby
require "bundler"
require "erlang/etf"
require "stringio"
```
Then, we can modify the `read_input` function to decode the byte sequence:

```ruby
def receive_input
  # ...

  Erlang.binary_to_term(STDIN.read(length))
end
```
The eval loop now needs to check that the input message is a tuple and that it contains the `:eval` atom as the first element:

```ruby
while (cmd = receive_input) do
  if cmd.is_a?(Erlang::Tuple) && cmd[0] == :eval
    eval(cmd[1], context)
  end
end
```
Then we need to adapt the `send_response` function to encode the response message as `{:response, value}`:

```ruby
def send_response(value)
  response = Erlang.term_to_binary(Erlang::Tuple[:response, value])
  # ...
end
```
Going back to the Elixir side, we now need to decode the response message with `:erlang.binary_to_term/1`:

```elixir
receive do
  {^port, {:data, result}} ->
    IO.puts("Elixir got: #{inspect :erlang.binary_to_term(result)}")
end

# Elixir got: {:response, 27}
```
Take special note how the received value is now an integer (previously it was a string). This happens because the response is now encoded to ETF on the Ruby side.

The complete code is available [here](https://gist.github.com/sasa1977/c03f3b86382d19ef4ec3).

## Bypassing stdio
Communication via stdio is somewhat unfortunate. If in the external program we want to print something, perhaps for debugging purposes, the output will just be sent back to Erlang. Luckily, this can be avoided by instructing Erlang to use file descriptors 3 and 4 for communication with the program. Possible caveat: I'm not sure if this feature will work on Windows.

The change is simple enough. We need to provide the `:nouse_stdio` option to `Port.open/2`:

```elixir
port = Port.open({:spawn, cmd}, [:binary, {:packet, 4}, :nouse_stdio])
```
Then, in Ruby, we need to open files 3 and 4, making sure that the output file is not buffered:

```ruby
@input = IO.new(3)
@output = IO.new(4)
@output.sync = true
```
Finally, we can simply replace references to `STDIN` and `STDOUT` with `@input` and `@output` respectively. The code is omitted for the sake of brevity.

After these changes, we can print debug messages from the Ruby process:

```ruby
while (cmd = receive_input) do
  if cmd.is_a?(Erlang::Tuple) && cmd[0] == :eval
    puts "Ruby: #{cmd[1]}"
    res = eval(cmd[1], context)
    puts "Ruby: => #{res.inspect}\n\n"
  end
end

puts "Ruby: exiting"
```
Which gives the output:

```
Ruby: a = 1
Ruby: => 1

Ruby:   while a < 10 do
    a *= 3
  end
Ruby: => nil

Ruby: send_response(a)
Ruby: => true

Elixir got: {:response, 27}
Ruby: exiting
```
The code is available [here](https://gist.github.com/sasa1977/d862a8107071651b34d0).

## Wrapping the port in a server process
Since the communication with the port relies heavily on message passing, it's worth managing the port inside a `GenServer`. This gives us some nice benefits:

- The server process can provide an abstract API to its clients. For example, we could expose `RubyServer.cast` and `RubyServer.call`. The first operation just issues a command without producing the output. The second one will instruct Ruby program to invoke `send_response` and send the response back. In addition, the server process will handle the response message by notifying the client process. The coupling between Erlang and the program remains in the code of the server process.
- The server process can include additional unique id in each request issued to the port. Ruby program will include this id in the response message, so the server can reliably match the response to a particular client request.
- The server process can be notified if the Ruby program crashes, and in turn crash itself.

Let's see an example usage of such server:

```elixir
{:ok, server} = RubyServer.start_link

RubyServer.cast(server, "a = 1")
RubyServer.cast(server, ~S"""
  while a < 10 do
    a *= 3
  end
""")

RubyServer.call(server, "Erlang::Tuple[:response, a]")
|> IO.inspect

# {:response, 27}
```
Of course, nothing stops you from creating another Ruby interpreter:

```elixir
{:ok, another_server} = RubyServer.start_link
RubyServer.cast(another_server, "a = 42")
RubyServer.call(another_server, "Erlang::Tuple[:response, a]")
|> IO.inspect

# {:response, 42}
```
These two servers communicate with different interpreter instances so there's no overlap:

```elixir
RubyServer.call(server, "Erlang::Tuple[:response, a]")
|> IO.inspect

# {:response, 27}
```
Finally, a crash in the Ruby program will be noticed by the `GenServer` which will in turn crash itself:

```elixir
RubyServer.call(server, "1/0")

# ** (EXIT from #PID<0.48.0>) an exception was raised:
#     ** (ErlangError) erlang error: {:port_exit, 1}
#         ruby_server.ex:43: RubyServer.handle_info/2
#         (stdlib) gen_server.erl:593: :gen_server.try_dispatch/4
#         (stdlib) gen_server.erl:659: :gen_server.handle_msg/5
#         (stdlib) proc_lib.erl:237: :proc_lib.init_p_do_apply/3
```
The implementation is mostly a rehash of the previously mentioned techniques, so I won't explain it here. The only new thing is providing of the `:exit_status` option to `Port.open/2`. With this option, we ensure that the owner process will receive the `{port, {:exit_status, status}}` message, and do something about the port crash. You're advised to try and implement such `GenServer` yourself, or analyze [my basic solution](https://gist.github.com/sasa1977/3bf1753675a77f18805a).

## Alternatives to ports
Like everything else, ports come with some associated trade-offs. The most obvious one is the performance hit due to encoding and communicating via pipes. If the actual processing in the port is very short, this overhead might not be tolerable. With a lot of hand waving I'd say that ports are more appropriate when the external program will do some "significant" amount of work, something that's measured at least in milliseconds.

In addition, ports are coupled to the owner (and vice-versa). If the owner stops, you probably want to stop the external program. Otherwise the restarted owner will start another instance of the program, while the previous instance won't be able to talk to Erlang anymore.

If these issues are relevant for your specific case, you might consider some alternatives:
- [Port drivers](http://www.erlang.org/doc/man/erl_driver.html) (sometimes called linked-in drivers) have characteristics similar to ports, but there is no external program involved. Instead, the code, implemented in C/C++, is running directly in the VM.
- [NIFs](http://www.erlang.org/doc/man/erl_nif.html) (native implemented functions) can be used to implement Erlang functions in C and run them inside the BEAM. Unlike port drivers, NIFs are not tied to a particular process.
- It is also possible to make your program look like an Erlang node. Some helper libraries are provided for [C and Java](http://www.erlang.org/doc/tutorial/overview.html#id60360). Your Erlang node can then communicate with the program, just like it would do with any other node in the cluster.
- Of course, you can always go the "microservices" style: start a separate program, and expose some HTTP interface so your Erlang system can talk to it.

The first two alternatives might give you significant speed improvement at the cost of safety. An unhandled exception in a NIF or port driver will crash the entire BEAM. Moreover, both NIFs and port-drivers are running in scheduler threads, so you need to keep your computations short (<= 1ms), otherwise you may end up compromising the scheduler. This can be worked around with threads and usage of dirty schedulers, but the implementation might be significantly more involved.

The third option provides looser coupling between two parties, allowing them to restart separately. Since distributed Erlang is used, you should still be able to detect crashes of the other side.

A custom HTTP interface is more general than an Erlang-like node (since it doesn't require an Erlang client), but you lose the ability to detect crashes. If one party needs to detect that the other party has crashed, you'll need to roll your own health checking (or reuse some 3rd party component for that).

I'd say that nodes and separate services seem suitable when two parties are more like peers, and each one can exist without the other. On the other hand, ports are more interesting when the external program makes sense only in the context of the whole system, and should be taken down if some other part of the system terminates.

As you can see, there are various options available, so I think it's safe to say that Erlang is not an island. Moving to Erlang/Elixir doesn't mean you lose the ability to implement some parts of the system in other languages. So if for whatever reasons you decide that something else is more suitable to power a particular feature, you can definitely take that road and still enjoy the benefits of Erlang/Elixir in the rest of your system.
