defmodule Satellite.Application do
  use Application

  def start(_, _) do
    Satellite.Supervisor.start_link
  end
end
