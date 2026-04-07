defmodule CoolifyEx.MixProject do
  use Mix.Project

  def project do
    [
      app: :coolify_ex,
      version: "0.5.1",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      preferred_cli_env: preferred_cli_env(),
      dialyzer: dialyzer(),
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:req, "~> 0.5.10"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false},
      {:bypass, "~> 2.1", only: :test}
    ]
  end

  defp description do
    "Generic Elixir toolkit for deploying, observing, and readiness-verifying Coolify apps"
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{
        "GitHub" => "https://github.com/nshkrdotcom/coolify_ex"
      },
      files: ~w(
        assets
        guides
        lib
        scripts
        coolify.example.exs
        mix.exs
        README.md
        LICENSE
        CHANGELOG.md
      )
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/coolify_ex.svg",
      source_url: "https://github.com/nshkrdotcom/coolify_ex",
      homepage_url: "https://github.com/nshkrdotcom/coolify_ex",
      assets: %{"assets" => "assets"},
      extras: [
        "README.md": [title: "Overview"],
        "guides/getting-started.md": [title: "Getting Started"],
        "guides/manifest.md": [title: "Manifest Format"],
        "guides/monorepos.md": [title: "Monorepos and Phoenix Apps"],
        "guides/remote-server.md": [title: "Remote Server Setup"],
        "guides/mix-tasks.md": [title: "Mix Tasks"],
        "CHANGELOG.md": [title: "Changelog"],
        LICENSE: [title: "License"]
      ],
      groups_for_extras: [
        Introduction: ~r/README.md|guides\/getting-started.md/,
        Configuration: ~r/guides\/manifest.md|guides\/monorepos.md/,
        Operations: ~r/guides\/remote-server.md|guides\/mix-tasks.md/,
        "Project Documents": ~r/CHANGELOG.md|LICENSE/
      ]
    ]
  end

  defp preferred_cli_env do
    [
      credo: :test,
      dialyzer: :dev
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:mix],
      plt_local_path: "priv/plts",
      flags: [:error_handling, :missing_return, :underspecs, :unknown]
    ]
  end
end
