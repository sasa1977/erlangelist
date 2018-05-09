defmodule Erlangelist.Mixfile do
  use Mix.Project

  def project do
    [
      app: :erlangelist,
      version: "0.0.1",
      elixir: "~> 1.4",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [release: :prod],
      aliases: [release: ["erlangelist.compile_assets", "phx.digest", "release"]]
    ]
  end

  def application do
    [
      mod: {Erlangelist.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:phoenix, "~> 1.3.2"},
      {:phoenix_pubsub, "~> 1.0"},
      {:phoenix_html, "~> 2.10"},
      {:gettext, "~> 0.11"},
      {:cowboy, "~> 1.0"},
      {:earmark, "~> 1.0"},
      {:httpoison, "~> 1.0"},
      {:site_encrypt, path: "../site_encrypt"},
      {:distillery, "~> 1.5", runtime: false},
      {:phoenix_live_reload, "~> 1.0", only: :dev}
    ]
  end
end
