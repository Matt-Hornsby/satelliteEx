defmodule Satellite.Mixfile do
  use Mix.Project

  def project do
    [
      app: :satellite_ex,
      version: "0.1.2",
      elixir: "~> 1.8",
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "satellite_ex",
      source_url: "https://github.com/Matt-Hornsby/satelliteEx"
    ]
  end

  def application do
    [applications: [:logger], mod: {Satellite.Application, []}]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.21", only: :dev},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.10", only: :test}
    ]
  end

  defp description() do
    "This is a satellite prediction library that provides satellite pass times for any given time and location."
  end

  defp package() do
    [
      name: "satellite_ex",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/Matt-Hornsby/satelliteEx"}
    ]
  end
end
