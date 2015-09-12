defmodule Erlangelist.Mixfile do
  use Mix.Project

  def project do
    [app: :erlangelist,
     version: "0.0.1",
     elixir: "~> 1.0",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [mod: {Erlangelist, []},
     applications: [
      :phoenix, :phoenix_html, :cowboy, :logger, :postgrex, :con_cache, :timex,
      :runtime_tools, :lager_logger, :lager, :exometer, :httpoison, :poison
    ]]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "web", "test/support"]
  defp elixirc_paths(_),     do: ["lib", "web"]

  # Specifies your project dependencies
  #
  # Type `mix help deps` for examples and options
  defp deps do
    [{:phoenix, "~> 1.0.0"},
     {:postgrex, ">= 0.0.0"},
     {:phoenix_html, "~> 2.1"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:cowboy, "~> 1.0"},
     {:earmark, "~> 0.1"},
     {:con_cache, "~> 0.8.1"},
     {:timex, "~> 0.19.2"},
     {:exrm, "~> 0.19.2"},
     {:exometer_core, github: "PSPDFKit-labs/exometer_core", override: true},
     {:exometer, github: "PSPDFKit-labs/exometer"},
     {:edown, github: "uwiger/edown", tag: "0.7", override: true},
     {:lager, "~> 2.1", override: true},
     {:lager_logger, "~> 1.0"},
     {:httpoison, "~> 0.7.3"},
     {:poison, "~> 1.5.0"},
   ]
  end
end
