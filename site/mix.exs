defmodule Erlangelist.Mixfile do
  use Mix.Project

  def project do
    [
      app: :erlangelist,
      version: "0.0.1",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      compilers: [:boundary, :phoenix, :gettext] ++ Mix.compilers(),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [release: :prod],
      aliases: [
        release: ["cmd npm run deploy --prefix ./assets", "phx.digest", "release"],
        test: ["erlangelist.clean", "test"],
        "boundary.visualize": ["boundary.visualize", &create_boundary_pngs/1]
      ],
      dialyzer: [plt_add_deps: :transitive, remove_defaults: [:unknown]],
      releases: [
        erlangelist: [
          include_executables_for: [:unix],
          steps: [:assemble, :tar],
          strip_beams: false
        ]
      ],
      boundary: boundary()
    ]
  end

  def application do
    [
      mod: {Erlangelist.App, []},
      extra_applications: [:logger, :runtime_tools, :os_mon]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:boundary, "~> 0.6.0", runtime: false},
      {:deep_merge, "~> 1.0"},
      {:dialyxir, "~> 1.0", runtime: false},
      {:earmark, "~> 1.4"},
      {:gettext, "~> 0.11"},
      {:jason, "~> 1.0"},
      {:makeup_elixir, "~> 0.14"},
      {:makeup_erlang, "~> 0.1"},
      {:mox, "~> 1.0", only: :test},
      {:phoenix_html, "~> 2.14"},
      {:phoenix_live_dashboard, "~> 0.2"},
      {:phoenix_live_reload, "~> 1.0", only: :dev},
      {:phoenix_pubsub, "~> 2.0"},
      {:phoenix, "~> 1.5.0"},
      {:provider, github: "verybigthings/provider"},
      {:plug_cowboy, "~> 2.1"},
      {:plug, "~> 1.7"},
      {:site_encrypt, github: "sasa1977/site_encrypt", branch: "upgrade-parent"},
      {:sshex, "~> 2.0", runtime: false},
      {:table_rex, "~> 3.0", runtime: false},
      {:telemetry_metrics, "~> 0.5"},
      {:telemetry_poller, "~> 0.4"}
    ]
  end

  defp boundary do
    [
      default: [
        check: [
          apps: [
            {:mix, :runtime},
            :phoenix
          ]
        ]
      ]
    ]
  end

  defp create_boundary_pngs(_args) do
    if System.find_executable("dot") do
      png_dir = Path.join(~w/boundary png/)
      File.rm_rf(png_dir)
      File.mkdir_p!(png_dir)

      Enum.each(
        Path.wildcard(Path.join("boundary", "*.dot")),
        fn dot_file ->
          png_file = Path.join([png_dir, "#{Path.basename(dot_file, ".dot")}.png"])
          System.cmd("dot", ~w/-Tpng #{dot_file} -o #{png_file}/)
        end
      )

      Mix.shell().info([:green, "Generated png files in #{png_dir}"])
    else
      Mix.shell().info([:yellow, "Install graphviz package to enable generation of png files."])
    end
  end
end
