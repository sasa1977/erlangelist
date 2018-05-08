defmodule LetsEncrypt.MixProject do
  use Mix.Project

  def project do
    [
      app: :lets_encrypt,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {LetsEncrypt.Application, []}
    ]
  end

  defp deps do
    [
      {:parent, github: "sasa1977/parent"},
      {:plug, "~> 1.5", optional: true}
    ]
  end
end
