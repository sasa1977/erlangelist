It is a great pleasure to announce that [The Erlangelist is now open-sourced](https://github.com/sasa1977/erlangelist). Last week I have made the switch to the completely rewritten, new version of the site, and with this post I'm also making the repository public.

## Changelog

From the end user's perspective there aren't many changes:

- Comments are now powered by Disqus.
- Some of the past articles are not migrated to the new site. You can still find them at the [old blogger site](http://theerlangelist.blogspot.com).
- All articles are now licensed under a under a [Creative Commons Attribution-NonCommercial 4.0 International License](http://creativecommons.org/licenses/by-nc/4.0/).
- [Privacy policy](/privacy_policy.html) is now included.
- The UI went through some minor cosmetic changes (though sadly it still reflects how much I suck at UI/UX).
- Article links have changed, but old urls still work. If your site points to this blog (thanks for the plug), the link should still work (even if pointing to a non-migrated article)

## Internals

The Erlangelist site was previously hosted on Blogger, but now it's fully rewritten from scratch and self-hosted on a cheap VPS. I plan on writing more in-depth posts in the future, but here's a general technical overview.

The site is powered by Elixir and Phoenix. All requests are accepted directly in the Erlang VM, i.e. there's no nginx or something similar in front.

PostgreSQL is used to store some data about each request, so I can later get some basic server usage stats (views, visitors, referers).

In addition, I'm running a local instance of the [freegeoip.net](https://github.com/fiorix/freegeoip) site, which allows me to determine your geolocation. Currently, only your country information is used. This is stored in the database request log, because I'd like to know where my visitors come from. In addition, I use this information to explicitly ask EU based users to allow usage of cookies.

Finally, Graphite is used to visualize some general stats. I use collectd to gather system metrics, and Exometer for some basic Erlang VM information.

All of the components (save collectd) are running inside Docker containers which are started as systemd units. The initial server setup is done with Ansible, and the deploy is performed with `git push` to the server.

## Why?

First of all, I want to point out the obvious: implementing a web server from scratch is clearly a wrong approach to write a blog.

It requires a lot of time and energy in dealing with the whole stack: backend implementation, frontend & UI, server administration, deployment, monitoring, and whatnot. And still, the final product is in many ways, if not all, inferior to alternatives such as Medium, GitHub pages, or Blogger. Such solutions allow you to focus on your writing without worrying about anything else. Furthermore, they are surely more stable and battle-tested, offer better reliability and higher capacity.

My implementation of the Erlangelist site lacks in all of these properties, being ridden with all the typical developer sins: NIH, over- and under- engineering, ad-hoc hacky shortcuts, home-grown patterns, wheel reinvention, poor testing, bash scripts (full confession: I love bash scripts), and many more. Also, hosting the blog on a single cheap VPS doesn't really boost its availability.

So, why did I do it then? Because I wanted to try out Phoenix and The Erlangelist was a good lab rat candidate. It's a pretty simple service and it's used in real life. Much to my surprise, people read these articles, and occasionally even mention some of them in their own posts. On the other hand, the blog receives only a few hundred views per day, so the site is really not highly loaded, nor super critical. Occasional shorter downtime shouldn't cause much disturbance, and it might even go completely unnoticed.

The challenge was thus manageable in the little extra time I was able to spare, and so far the system seems to be doing well. As an added bonus, now I'm able to see all the requests, something that was not possible on Blogger. One thing I immediately learned after switching to the new site is that people seem to use the RSS feed of the blog. I had no idea this was still a thing, and almost forgot to port the feed. Thanks to Janis Miezitis for providing [nice RSS on Phoenix guide](http://codingwithaxe.com/how-to-write-rss-feed-in-phoenix/).


## The experience

I had a great time implementing this little site. The server code is fairly simple, and doesn't really use a lot of Phoenix. The site boils down to hosting a few static pages, so there wasn't much need for some fancy features such as channels. Regardless, I was quite impressed with what I've seen so far. It was pretty easy to get started, especially owing to [excellent online guides](http://www.phoenixframework.org/docs/overview) by [Lance Halvorsen](https://twitter.com/lance_halvorsen).

Working on the "devops" tasks related to producing and deploying the release was another interesting thing. This is where I spent most of the effort, but I've also learned a lot in the process.

So altogether, the experience so far has been pretty nice, and I'm very excited that this blog is finally powered by the same technology it promotes :-)
