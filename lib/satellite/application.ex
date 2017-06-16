defmodule Satellite.Application do
  use Application

  def start(_, _) do
    import Supervisor.Spec

    children = [
      worker(Satellite.SatelliteDatabase, []),
      worker(Satellite.MagnitudeDatabase, [])
    ]

    opts = [strategy: :one_for_one, name: Satellite.Supervisor]

    Supervisor.start_link(children, opts)
  end
end
