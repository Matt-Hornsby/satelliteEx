defmodule Satellite.Passes do
  @moduledoc """
  This module provides functionality to pull satellite orbit information from
  Celestrak and to predict visible satellite passes from a specified location
  on Earth.

  ## Examples

  iss_satrec = Satellite.SatelliteDatabase.lookup("ISS (ZARYA)")
  seattle = %Observer{
    longitude: -122.3321 * Constants.deg2rad,
    latitude: 47.6062 * Constants.deg2rad,
    height: 0.370
  }
  Satellite.Passes.current_position({{2016, 12, 24}, {12, 12, 12}}, seattle, iss_satrec)
  """

  require Satellite.Constants
  alias Satellite.{Constants, CoordinateTransforms}
  import Satellite.Dates
  import Sun.SunlightCalculations
  import Sun.SunPosition
  require Logger

  #
  # PUBLIC
  #

  def list_passes(satrec, count, observer, start_datetime) when count > 0 do
    startPass = next_pass(satrec, start_datetime, observer)
    list_passes(satrec, count - 1, observer, startPass.end_time, [startPass])
  end
  def list_passes(_satrec, 0, _observer, _start_datetime, passes), do: passes
  def list_passes(satrec, count, observer, start_datetime, passes) do

    new_time = (:calendar.datetime_to_gregorian_seconds(start_datetime) + 1)
              |> :calendar.gregorian_seconds_to_datetime

    this_pass = next_pass(satrec, new_time, observer)

    list_passes(satrec, count - 1, observer, this_pass.end_time, passes ++ [this_pass])
  end

  def next_pass(satrec, {{_year, _month, _day}, {_hour, _min, _sec}} = start_date,
                          %{longitude: _, latitude: _, height: _} = observer) do
      pass = find_first_pass_for(start_date, observer, satrec)
      start_prediction = predict_for(pass.start_of_pass.datetime, observer, satrec)
      end_prediction = predict_for(pass.end_of_pass.datetime, observer, satrec)

      best_part_of_pass = brightest_part_of_pass(
          pass.start_of_pass.datetime, pass.end_of_pass.datetime, observer, satrec, start_prediction)

      visibility = visibility(best_part_of_pass.sun_position.elevation_radians, best_part_of_pass.satellite_magnitude)

      %{
        start_time: pass.start_of_pass.datetime,
        start_azimuth: start_prediction.azimuth_in_degrees,
        end_time: pass.end_of_pass.datetime,
        end_azimuth: end_prediction.azimuth_in_degrees,
        start_magnitude: start_prediction.satellite_magnitude,
        end_magnitude: end_prediction.satellite_magnitude,
        best_part_of_pass: best_part_of_pass,
        visibility: visibility
      }
  end

  def current_position(satrec, observer) do
    now = :calendar.universal_time()
    now_secs = :calendar.datetime_to_gregorian_seconds(now)
    new_secs = now_secs + (3600 * 13) + (60 * 30)
    new_dt = :calendar.gregorian_seconds_to_datetime(new_secs) |> :calendar.universal_time_to_local_time
    predict_for(new_dt, observer, satrec)
  end

  #
  # PRIVATE
  #

  defp predict_for({{year, month, day}, {hour, min, sec}} = input_date,
                  %{longitude: _, latitude: _, height: _} = observer,
                  satellite_record) do

    gmst = gstime(jday(year,month,day,hour,min,sec))
    positionAndVelocity = Satellite.SGP4.propagate(satellite_record,year,month,day,hour,min,sec)
    positionEci = positionAndVelocity.position
    #velocityEci = positionAndVelocity.velocity
    positionEcf = CoordinateTransforms.eci_to_ecf(positionEci, gmst)
    lookAngles = CoordinateTransforms.ecfToLookAngles(observer, positionEcf)
    sun_position = get_position_at(input_date, observer)
    #sunlit = sunlit?(positionEci, sun_position)
    sunlit = calculate_sunlit_status(positionEci, sun_position)

    # TODO: Need to convert this project to a supervised application and
    # start this GenServer from a supervisor
    #{:ok, pid} = Satellite.MagnitudeDatabase.start_link
    #{:ok, satmag} = Satellite.MagnitudeDatabase.lookup(pid, satellite_record.satnum)
    #IO.puts "Found satellite magnitude from database: #{satmag}"

    #HACK: Hardcoding the base magnitude for ISS here...
    satmag = -0.5

    magnitude = cond do
      sunlit == true -> get_base_magnitude(satmag, positionEci, sun_position, observer, gmst)
      true -> 999 # Not sunlit, so set magnitude to something really faint
    end

    adjusted_magnitude = magnitude
                          |> adjust_magnutide_for_low_elevation(lookAngles.elevation * Constants.rad2deg)
                          |> adjust_magnitude_for_sunset(sun_position.elevation_radians)

    %{
      datetime: input_date,
      elevation_in_degrees: lookAngles.elevation * Constants.rad2deg,
      azimuth_in_degrees: lookAngles.azimuth * Constants.rad2deg,
      range: lookAngles.rangeSat,
      sunlit?: sunlit,
      satellite_magnitude: magnitude,
      min_wp: adjusted_magnitude,
      sun_position: sun_position
    }
  end

  defp visibility(sun_elevation, _satellite_magnitude) when sun_elevation > 0.0, do: [:not_visible, :none]
  defp visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 5.0, do: [:visible, :naked_eye]
  defp visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 8.0, do: [:visible, :binoculars]
  defp visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 10.0, do: [:visible, :small_telescope]
  defp visibility(_sun_elevation, _satellite_magnitude), do: [:visible, :telescope]

  defp brightest_part_of_pass(start_of_pass, end_of_pass, observer, satrec, best_pass) when start_of_pass < end_of_pass do
    current_part_of_pass = predict_for(start_of_pass, observer, satrec)
    #IO.inspect start_of_pass
    #IO.inspect "elevation: #{current_part_of_pass.elevation_in_degrees} min_wp: #{current_part_of_pass.min_wp} satellite_magnitude:#{current_part_of_pass.satellite_magnitude} sun_elevation:#{current_part_of_pass.sun_position.elevation_radians}"

    current_best_pass = if (current_part_of_pass.min_wp < best_pass.min_wp)
                            && (current_part_of_pass.sun_position.elevation_radians < 0) do
                              current_part_of_pass
                            else
                              best_pass
                            end

    # TODO if this magnitude is lower (brighter) than the last try (and the sun is still below the horizon), then use this one
    # vsft.js: 422 - need to incorporate this line with the minWP part (current_part_of_pass.minWP)
    # TODO better way of determining increment? like vsft.js: 387
    next_time = increment_date(start_of_pass, 5)
    brightest_part_of_pass(next_time, end_of_pass, observer, satrec, current_best_pass)
  end
  defp brightest_part_of_pass(_start_of_pass, _end_of_pass, _observer, _satrec, current_best_pass), do: current_best_pass

  defp find_first_pass_for({{_year, _month, _day}, {_hour, _min, _sec}} = start_date,
                          %{longitude: _, latitude: _, height: _} = observer,
                          satellite_record) do

    first_prediction = predict_for(start_date, observer, satellite_record)
    start_of_pass = first_positive_elevation(start_date, observer, satellite_record, first_prediction.elevation_in_degrees, first_prediction.azimuth_in_degrees)
    end_of_pass = last_positive_elevation(start_of_pass.datetime, observer, satellite_record, 0.0, 0.0)

    %{start_of_pass: start_of_pass, end_of_pass: end_of_pass}
  end

  defp first_positive_elevation(start_date, observer, satellite_record, elevation, _azimuth) when elevation <= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"

    # increment coarsly
    new_start_date = increment_date(start_date, 60)
    prediction = predict_for(new_start_date, observer, satellite_record)
    first_positive_elevation(new_start_date, observer, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp first_positive_elevation(start_date, observer, satellite_record, elevation, azimuth) do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "*** #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation} ***"

    # now back off finely
    #IO.puts ("Now backing off...")
    decrement_to_lowest_elevation(start_date, observer, satellite_record, elevation, azimuth)
  end

  defp decrement_to_lowest_elevation(start_date, observer, satellite_record, elevation, _azimuth) when elevation > 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"

    new_start_date = increment_date(start_date, -1)
    prediction = predict_for(new_start_date, observer, satellite_record)
    decrement_to_lowest_elevation(new_start_date, observer,  satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp decrement_to_lowest_elevation(start_date, _observer, _satellite_record, elevation, azimuth) do
    local_date = :calendar.universal_time_to_local_time(start_date)
    {{yy, mm, dd},{h, m, s}} = local_date
    IO.puts "*** START TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local) ***"
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  defp last_positive_elevation(start_date, observer, satellite_record, elevation, _azimuth) when elevation >= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"
    # Increment until satellite goes below horizon
    new_start_date = increment_date(start_date, 1)
    prediction = predict_for(new_start_date, observer, satellite_record)
    last_positive_elevation(new_start_date, observer, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp last_positive_elevation(start_date, _observer, _satellite_record, elevation, azimuth) do
    # End case - we are now at a negative elevation so return the datetime in local time
    local_date = :calendar.universal_time_to_local_time(start_date)
    {{yy, mm, dd},{h, m, s}} = local_date
    Logger.debug "Test"
    IO.puts "*** END TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local) ***"
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  defp increment_date(date, seconds) do
    start_seconds = :calendar.datetime_to_gregorian_seconds(date)
    start_seconds + seconds |> :calendar.gregorian_seconds_to_datetime
  end
end