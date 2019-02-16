defmodule Satellite.Application do
  use Application

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Satellite.MagnitudeDatabase, []),
      # <-- Must start after MagnitudeDatabase
      worker(Satellite.SatelliteDatabase, [])
    ]

    opts = [strategy: :one_for_one, name: Satellite.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
