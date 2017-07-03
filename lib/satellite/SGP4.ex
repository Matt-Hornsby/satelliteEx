defmodule Satellite.SGP4 do
  alias __MODULE__

  def new(satrec, init_parameters) do
    SGP4.Init.init(satrec, init_parameters)
  end

  def calculate(satrec, tsince) do
    SGP4.Model.calculate(satrec, tsince)
  end

  def propagate(satrec, {{year, month, day}, {hour, minute, second}}) do
    SGP4.Model.propagate(satrec, {{year, month, day}, {hour, minute, second}})
  end
end
