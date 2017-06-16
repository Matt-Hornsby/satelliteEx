defmodule Satellite.Application do
  use Application

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Satellite.MagnitudeDatabase, []),
      worker(Satellite.SatelliteDatabase, []), # <-- Must start after MagnitudeDatabase
    ]

    opts = [strategy: :one_for_one, name: Satellite.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
