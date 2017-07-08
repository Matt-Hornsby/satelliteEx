defmodule Satellite do
  alias Observer.KnownLocations
  alias Satellite.{SatelliteDatabase, Passes}
  #
  # Public API
  #

  def list_passes(satrec, count, observer, start_datetime) do
    Passes.list_passes(satrec, count, observer, start_datetime)
  end

  def list_passes_until(satrec, observer, start_datetime, end_datetime) do
    Passes.list_passes_until(satrec, observer, start_datetime, end_datetime)
  end

  def next_pass(satrec, start_datetime, observer) do
    Passes.next_pass(satrec, start_datetime, observer)
  end

  def current_position(satrec, observer) do
    Passes.current_position(satrec, observer)
  end

  #
  # Seattle- and ISS-specific stuff
  #

  def find_next_iss_pass_for_seattle do
    next_pass(iss_satrec(), :calendar.universal_time, seattle_observer())
  end

  def locate_current_iss_position_for_seattle do
    current_position(iss_satrec(), seattle_observer())
  end

  def find_iss_passes(count, observer, start_datetime) do
    list_passes(iss_satrec(), count, observer, start_datetime)
  end

  def find_next_iss_pass(start_datetime, observer) do
    next_pass(iss_satrec(), start_datetime, observer)
  end

  defp seattle_observer, do: KnownLocations.seattle
  defp iss_satrec, do: SatelliteDatabase.lookup(25_544)

end
