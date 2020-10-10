About two years ago I decided to add HTTPS support to this site, using automatic certification via Let's Encrypt. All the articles on the subject relied on a tool called [certbot](https://certbot.eff.org/). A couple of variations were mentioned, some requiring the tool to run while the site is down, others using nginx + certbot combination. It seemed that installing and running some additional external tool(s) in production was mandatory.

At that point The Erlangelist was a standalone Elixir-powered system which required no external program. It seemed that now I have to start worrying about setting up additional services and interact with them using their custom DSLs. This would complicate operations, and create a disconnect between production and development. Any changes to the certification configuration would need to be tested directly in production, or alternatively I'd have to setup a staging server. Either way, testing of certification would be done manually.

Unhappy with this state I started the work on [site_encrypt](https://hexdocs.pm/site_encrypt/readme.html), a library which takes a different approach to automatic certification:

1. site_encrypt is a library dependency, not an external tool. You're not required to install any OS-level package to use it.
2. The certification process and periodical renewal are running in the same OS process as the rest of the system. No other OS processes need to be started.
3. Everything is configured in the same project where the system is implemented.
4. Interaction with site_encrypt is done via Elixir functions and data. No yaml, ini, json, or other kind of DSL is required.
5. It's trivial to run the certification locally, which reduces the differences between prod and local dev.
6. The support for automatic testing of the certification is provided. There's no need to setup staging machines, or make changes directly on the production system.

This is an example of what I call "integrated operations". Instead of being spread across a bunch of yamls, inis, jsons, and bash scripts, somehow all glued together at the OS-level, most of the operations is done in development, i.e. the same place where the rest of the system is implemented, using the same language. Such approach significantly reduces the technical complexity of the system. The Erlangelist is mostly implemented in Elixir, with only a few administrative tasks, such as installation of OS packages, users creation, port forwarding rules, and similar provisioning tasks being done outside of Elixir.

This also simplifies local development. The [instructions to start the system locally](https://github.com/sasa1977/erlangelist/#running-the-site-locally) are very simple:

1. Install build tools (Elixir, Erlang, nodejs)
2. Fetch dependencies
3. Invoke a single command to start the system

The locally started system will be extremely close to the production version. There is almost nothing of significance running on production which is not running locally. The only two differences of note I can think of are:

1. Ports 80/443 are forwarded in prod
2. The prod version uses Lets Encrypt for certification, while the local version uses a local CA server (more on this later).

Now, this may not sound like much for a simple blog host, but behind the scene The Erlangelist is a bit more than a simple request responder:

1. The Erlangelist system runs two separate web servers. The public facing server is the one you use to read this article. Another internal server uses the [Phoenix Live Dashboard](https://hexdocs.pm/phoenix_live_dashboard/Phoenix.LiveDashboard.html) to expose some metrics.
2. A small hand-made database is running which collects, aggregates, and persists the reading stats, periodically removing older stats from the disk.
3. The system periodically renews the certificate.
4. Locally and on CI, another web server which acts as a local certificate authority (CA) is running.

In other words, The Erlangelist is more than just a blog, a site, a server, or an app. It's a system consisting of multiple activities which collectively work together to support the full end-user service, as well as the operational aspects of the system. All of these activities are running concurrently. They don't block each other, or crash each other. The system utilizes all CPU cores of its host machine. For more details on how this works take a look at my talk [The soul of Erlang and Elixir](https://www.youtube.com/watch?v=JvBT4XBdoUE).

Let's take a closer look at site_encrypt.

## Certification

Let's Encrypt supports automatic certification via the [ACME (Automatic Certificate Management Environment) protocol](https://tools.ietf.org/html/rfc8555). This protocol describes the conversation between the client, which is a system wanting to obtain the certificate for some domain, and the server, which is the certificate authority (CA) that can create such certificate. In ACME conversation, our system asks the CA to provide the certificate for some domain, and the CA asks us to prove that we're the owners of that domain. The CA gives us some random bytes, and then makes a request at our domain, expecting to get those same bytes in return. This is also called a challenge. If we successfully respond to the challenge, the CA will create the certificate for us. The real story is of course more involved, but this simplified version hopefully gives you the basic idea.

This conversation is an activity of the system. It's a job which needs to be occasionally done to allow the system to provide the full service. If we don't do the certification, we don't have a valid certificate, and most people won't use the site. Likewise, if I decide to shut the site down, the certification serves no purpose anymore.

In such situations my preferred approach is to run this activity together with the rest of the system. The less fragmented the system is, the easier it is to manage. Running some part of the system externally is fine if there are stronger reasons, but I don't see such reasons in this simple scenario.

[site_encrypt makes this task straightforward](https://hexdocs.pm/site_encrypt/readme.html#quick-start). Add a library dep, fill in some blanks, and you're good to go. The certification configuration is provided by defining the `certification` function:

```elixir
def certification do
  SiteEncrypt.configure(
    client: :native,
    domains: ["mysite.com", "www.mysite.com"],
    emails: ["contact@mysite.com", "another_contact@mysite.com"],
    db_folder: "/folder/where/site_encrypt/stores/files",
    directory_url: directory_url(),
  )
end
```

This code looks pretty declarative, but it is executable code, not just a collection of facts. And that means that we have a lot of flexibility to shape the configuration data however we want. For example, if we want to make the certification parameters configurable by the system operator, say via a yaml file, nothing stops us from invoking `load_configuration_from_yaml()` instead of hardcoding the data. Say we want to make only some parameters configurable (e.g. domains and email), while leaving the rest hardcoded. We can simply do `Keyword.merge(load_some_params_from_yaml(), hardcoded_data)`. Supporting other kinds of config sources, like etcd or a database, is equally straightforward. You can always build declarative on top of imperative, while the opposite will require some imagination and trickery, such as running external configuration generators, and good luck managing that in production :-)

It's also worth mentioning that site_encrypt internally ships with two lower-level modules, a sort of plumbing to this porcelain. There is a [mid-level module](https://hexdocs.pm/site_encrypt/SiteEncrypt.Acme.Client.html#content) which provides workflow-related operations, such as "create an account", or "perform the certification", and a [lower-level module](https://hexdocs.pm/site_encrypt/SiteEncrypt.Acme.Client.API.html#content) which provides basic ACME client operations. These modules can be used when you want a finer grained control over the certification process.

## Reducing the dev-production mismatch

There's one interesting thing happening in the configuration presented earlier:

```elixir
def certification do
  SiteEncrypt.configure(
    # ...
    directory_url: directory_url(),
  )
end
```

The `directory_url` property defines the CA where site_encrypt will obtain the certificate. Instead of hardcoding this url, we're invoking a function to compute it. This happens because we need to use different urls for production vs staging vs local development. Let's take a look:

```elixir
defp directory_url do
  case System.get_env("MODE", "local") do
    "production" -> "https://acme-v02.api.letsencrypt.org/directory"
    "staging" -> "https://acme-staging-v02.api.letsencrypt.org/directory"
    "local" -> {:internal, port: 4002}
  end
end
```

Here, we're distinguishing production from staging from development based on the `MODE` OS env (easily replaceable with other source, owing to programmable API). If the env is not provided, we'll assume that the system running locally.

On a production machine, we go to the real CA, while for staging we'll use Let's Encrypt staging site. But what about the `{:internal, port: 4002}` thing which we use in local development? If we pass this particular shape of data to site_encrypt, an internal ACME server will be started on the given port, a sort of a local mock of Let's Encrypt. This server is running inside the same same OS process as the rest of the system.

So locally, site_encrypt will start a mock of Let's Encrypt, and it will use that mock to obtain the certificate. In other words, locally the system will certify itself. Here's an example of this in action on a local version of The Erlangelist:

```text
$ iex -S mix phx.server

[info]  Running Erlangelist.Web.Blog.Endpoint at 0.0.0.0:20080 (http)
[info]  Running Erlangelist.Web.Blog.Endpoint at 0.0.0.0:20443 (https)
[info]  Running local ACME server at port 20081
[info]  Creating new ACME account for domain theerlangelist.com
[info]  Ordering a new certificate for domain theerlangelist.com
[info]  New certificate for domain theerlangelist.com obtained
[info]  Certificate successfully obtained!
```

## Testability

Since local Erlangelist behaves exactly as the real one, we can test more of the system behaviour. For example, even on the local version HTTP requests are redirected to HTTPS. Here's a test verifying this:

```elixir
test "http requests are redirected to https" do
  assert redirected_to(Client.get("http://localhost/"), 301) ==
    "https://localhost/"
end
```

Likewise, redirection to www can also be tested:

```elixir
test "theerlangelist.com is redirected to www.theerlangelist.com" do
  assert redirected_to(Client.get("https://theerlangelist.com/"), 301)
    == "https://www.theerlangelist.com/"
end
```

In contrast, external proxy rules, such as those defined in Nginx configuration are typically not tested, which means that some change in configuration might break something else in a way which is not obvious to the operator.

In addition, site_encrypt ships with a small helper for testing the certification. Here's the relevant test:

```elixir
test "certification" do
  clean_restart(Erlangelist.Web.Blog.Endpoint)
  cert = get_cert(Erlangelist.Web.Blog.Endpoint)
  assert cert.domains == ~w/theerlangelist.com www.theerlangelist.com/
end
```

During this test, the blog endpoint (i.e. the blog web server) will be restarted, with all previously existing certificates removed. During the restart, the endpoint will be certified via the local ACME server. This certification will go through the whole process, with no mocking (save for the fact that a local CA is used). HTTP requests will be made, some keys will be generated, the system will call CA, which will then concurrently make a request to the system, and ultimately the certificate will be obtained.

Once that's all finished, the invocation of `get_cert` will establish an ssl connection to the blog server and fetch the certificate of the peer. Then we can assert the expected properties of the certificate.

Having such tests significantly increases my confidence in the system. Of course, there's always a chance of something going wrong in production (e.g. if DNS isn't correctly configured, and Let's Encrypt can't reach my site), but the possibility of errors is reduced, not only because of the tests, but also because a compiled language is used. For example, if I make a syntax error while changing the configuration, the code won't even compile, let alone make it to production. If I make a typo, e.g. by specifying `theerlangelist.org` instead of `theerlangelist.com`, the certification test will fail. In contrast, external configurations are much harder to test, and so they typically end up being manually verified on staging, or in some cases only in production.

## More automation

Beyond just obtaining the certificate, site_encrypt will periodically renew it. A periodic job is executed three times a day. This job checks the expiry date of the certificate, and starts the renewal process if the certificate is about to expire in 30 days. In addition, every time a certificate is obtained, site_encrypt can optionally generate a backup of its data. When the system is starting, if the site_encrypt database folder isn't present and the backup file exists, site_encrypt will automatically restore the database from the backup.

As a user of site_encrypt you have to do zero work to make this happen, which significantly reduces the amount of operational work required, bringing the bulk of it to the regular development.

For more elaborate backup scenarios, site_encrypt provides a callback hook. In your endpoint module you can define the function which is invoked after the certificate is obtained. You can use this function to e.g. store the cert in an arbitrary secure storage of your choice. Notice how this becomes a part of the regular system codebase, which is the most convenient and logical place to express such task. The fact that this is running together with the rest of the system, also means it's testable. Testing that the new certificate is correctly stored to desired storage is straightforward.

## Tight integration

Since it runs in the same OS process, and is powered by the same language, site_encrypt can integrate much better with its client, which leads to some nice benefits. I mentioned earlier that certification is a conversation between our system and the CA server. Now, when we're using the certbot tool, this dialogue turns into a three-party conversation. Instead of our system asking for the certificate, we ask certbot to do this on our behalf. However, the CA verification request (aka challenge) needs to be served by our site. Now, since certbot is an external tool, it treats our site as an opaque box. As a result, certbot doesn't know when we responded to the CA challenge, and so it has to be a bit more conservative. Namely, certbot will sleep for about three seconds before it starts polling CA to see if the challenge has been answered.

The native Elixir ACME client runs in the same OS process, and so it can integrate much better. The ACME client is informed by the challenge handler that the challenge is fulfilled, and so it can use a much shorter delay to start polling the CA. In production this optimization isn't particularly relevant, but on local dev, and especially in tests the difference becomes significant. The certification test via certbot takes about 6 seconds on my machine. The same test via the native client is about 800ms.

This tight integration offers some other interesting possibilities. With a bit of changes to the API, site_encrypt could support arbitrary storage for its database. It could also support coordination between multiple nodes, making it possible to implement a distributed certification, where an arbitrary node in the cluster initiates the certification, while any other node can successfully respond to the challenge, including even the nodes which came online after the challenge has been started.

## Operations

With the bulk of the system behaviour described in Elixir code, the remaining operational tasks done outside of Elixir are exclusively related to preparing the machine to run the Erlangelist. These tasks involve creating necessary accounts, creating the folder structure, installing required OS packages (essentially just Docker is needed), and setting up a single systemd unit for starting the container.

The production is dockerized, but the production docker image is very lightweight:

```text
FROM alpine:3.11 as site

RUN apk --no-cache upgrade && apk add --no-cache ncurses

COPY --from=builder /opt/app/site/_build/prod/rel/erlangelist /erlangelist

VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/db
VOLUME /erlangelist/lib/erlangelist-0.0.1/priv/backup

WORKDIR /erlangelist
ENTRYPOINT ["/erlangelist/bin/erlangelist"]
```

The key part is the `COPY` instruction which adds the built release of the system to the image. This release will contain all the compiled binaries, as well as a minimal Erlang runtime system, and is therefore pretty much self-contained, requiring only one small OS-level package to be installed.

## Final thoughts

Some might argue that using certbot with optionally Nginx or Caddy is simple enough, and I wouldn't completely disagree. It's perfectly valid to reach for external products to solve a technical challenge not related to the business domain. Such products can help us solve our problem quickly and focus on our core challenges. On the other hand, I feel that we should be more critical of the problems introduced by such products. As I've tried to show in this simple example, the integrated operations approach reduces the amount of moving parts and technologies used, bridges the gap between production and development, and improves the testability of the system. The implementation is simpler and at the same time more flexible, since the tool is driven by functions and data.

For this approach to work, you need a runtime that supports managing multiple system activities. BEAM, the runtime of Erlang and Elixir, makes this possible. For example, in many cases serving traffic directly with Phoenix, without having a reverse proxy in front of it, will work just fine. Features such as ETS tables or GenServer will reduce the need for tools like Redis. Running periodic jobs, regulating load, rate-limiting, pipeline processing, can all be done directly from Elixir, without requiring any external product.

Of course, there will always be cases where external tools will make more sense. But there will also be many cases where integrated approach will work just fine, especially in smaller systems not operating at the level of scale or complexity of Netflix, Twitter, Facebook, and similar. Having both options available would allow us to start with simple and move to an external tool only in more complicated scenarios.

This is the reason why I started the work on site_encrypt. The library is still incomplete and probably buggy, but these are issues that can be fixed with time and effort :-) I believe that the benefits of this approach are worth the effort, so I'll continue the work on the library. I'd like to see more of such libraries appearing, giving us simpler options for challenges such as load balancing, proxying, or persistence. As long as there are technical challenges where running an external product is the only option, there is opportunity for simplification, and it's up to us, the developers, to make that happen.
