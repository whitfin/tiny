defmodule Tiny.Mixfile do
  use Mix.Project

  @url_docs "http://hexdocs.pm/tiny"
  @url_github "https://github.com/zackehh/tiny"

  def project do
    [app: :tiny,
     description: "Tiny JSON parser for Elixir",
     version: "1.0.0",
     elixir: "~> 1.2",
     deps: deps(),
     package: %{
       files: [
         "lib",
         "mix.exs",
         "LICENSE",
         "README.md"
       ],
       licenses: [ "MIT" ],
       links: %{
         "Docs" => @url_docs,
         "GitHub" => @url_github
       },
       maintainers: [ "Isaac Whitfield" ]
     },
     docs: [
       extras: [ "README.md" ],
       source_ref: "master",
       source_url: @url_github
     ]]
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
      # Dependencies only used for local development and testing
      { :credo,  "~> 0.5",  optional: true, only: [ :dev, :test ] },
      { :ex_doc, "~> 0.14", optional: true, only: [ :dev, :test ] },
      { :exprof, "~> 0.2",  optional: true, only: [ :dev, :test ] }
    ]
  end
end
