defmodule Tiny.Mixfile do
  use Mix.Project

  @version "1.0.2"
  @url_docs "http://hexdocs.pm/tiny"
  @url_github "https://github.com/whitfin/tiny"

  def project do
    [
      app: :tiny,
      name: "Tiny",
      description: "Tiny JSON parser for Elixir",
      package: %{
        files: [
          "lib",
          "mix.exs",
          "LICENSE",
          "README.md"
        ],
        licenses: ["MIT"],
        links: %{
          "Docs" => @url_docs,
          "GitHub" => @url_github
        },
        maintainers: ["Isaac Whitfield"]
      },
      version: @version,
      elixir: "~> 1.2",
      deps: deps(),
      docs: [
        extras: ["README.md"],
        source_ref: "main",
        source_url: @url_github
      ],
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        docs: :docs,
        credo: :lint
      ]
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger]]
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
      {:ex_doc, "~> 0.29", optional: true, only: [:docs]}
    ]
  end
end
