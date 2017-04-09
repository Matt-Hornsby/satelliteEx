defmodule Satellite.Supervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, nil, name: :database_supervisor)
  end

  def init(_) do
    processes = [
      worker(Satellite.SatelliteDatabase, []),
      worker(Satellite.MagnitudeDatabase, [])
    ]
    supervise(processes, strategy: :one_for_one)
  end
end
