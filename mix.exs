defmodule Flexagon.Mixfile do
  use Mix.Project

  def project do
    [app: :flexagon,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     aliases: aliases
   ]
  end

  # Some command line aliases
  def aliases do
    [serve: ["run", &Flexagon.start/1]]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :cowboy, :httpoison, :plug, :poison],
     mod: {Flexagon, []},
     env: [
       target: "localhost:5984",
       scope_target: "registry.npmjs.com",
       port: 4001
     ]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy, "~> 1.0.0"},
      {:exrm, "~> 1.0.5"},
      {:httpoison, "~> 0.8.3"},
      {:plug, "~> 1.1.5"},
      {:poison, "~> 2.1.0"}
    ]
  end
end
