defmodule SiteEncrypt.MixProject do
  use Mix.Project

  def project do
    [
      app: :site_encrypt,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SiteEncrypt.Application, []}
    ]
  end

  defp deps do
    [
      {:parent, github: "sasa1977/parent"},
      {:plug, "~> 1.5", optional: true},
      {:jason, "~> 1.0"},
      {:jose, "~> 1.8"}
    ]
  end
end
