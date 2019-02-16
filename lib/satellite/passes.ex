defmodule Satellite.Passes do
  @moduledoc """
  Provides a set of algorithms to predict satellite passes over
  any location on Earth.

  ## Examples

  iss_satrec = Satellite.SatelliteDatabase.lookup("ISS (ZARYA)")
  seattle = Observer.KnownLocations.seattle
  Satellite.Passes.current_position(iss_satrec, seattle)
  """

  require Satellite.Constants

  import Sun.SunlightCalculations
  import Sun.SunPosition
  alias Satellite.{SGP4, CoordinateTransforms, Constants, Dates}
  require Logger

  #
  # PUBLIC
  #

  def list_passes(satrec, count, observer, start_datetime) when count > 0 do
    first_pass = next_pass(satrec, start_datetime, observer)
    list_passes(satrec, count - 1, observer, first_pass.end_time, [first_pass])
  end

  def list_passes_until(satrec, observer, start_datetime, end_datetime) when end_datetime >= start_datetime do
    first_pass = next_pass(satrec, start_datetime, observer)
    if first_pass.start_time > end_datetime do
      []
    else
      list_passes_until(satrec, observer, first_pass.end_time, end_datetime, [first_pass])
    end
  end

  def next_pass(satrec, {{_year, _month, _day}, {_hour, _min, _sec}} = start_date,
                          %{longitude_rad: _, latitude_rad: _, height_km: _} = observer) do
      pass = find_first_pass_for(start_date, observer, satrec)
      start_prediction = predict_for(pass.start_of_pass.datetime, observer, satrec)
      end_prediction = predict_for(pass.end_of_pass.datetime, observer, satrec)

      # Calculate peak by predicting halfway through the pass
      start_seconds = :calendar.datetime_to_gregorian_seconds(start_prediction.datetime)
      end_seconds = :calendar.datetime_to_gregorian_seconds(end_prediction.datetime)
      max_seconds = trunc((start_seconds + end_seconds) / 2)
      max_datetime = :calendar.gregorian_seconds_to_datetime(max_seconds)
      max_prediction = predict_for(max_datetime, observer, satrec)

      brightest_part_of_pass = brightest_part_of_pass(
          pass.start_of_pass.datetime, pass.end_of_pass.datetime, observer, satrec, start_prediction)

      visibility = visibility(brightest_part_of_pass.sun_position.elevation_radians, brightest_part_of_pass.satellite_magnitude)

      %{
        start_time: pass.start_of_pass.datetime,
        start_azimuth: start_prediction.azimuth_in_degrees,
        end_time: pass.end_of_pass.datetime,
        end_azimuth: end_prediction.azimuth_in_degrees,
        start_magnitude: start_prediction.satellite_magnitude,
        end_magnitude: end_prediction.satellite_magnitude,
        brightest_part_of_pass: brightest_part_of_pass,
        visibility: visibility,

        # Added:
        satnum: satrec.satnum,
        aos: start_prediction,
        max: max_prediction,
        los: end_prediction,
      }
  end

  def current_position(satrec, observer) do
    predict_for(:calendar.universal_time, observer, satrec)
  end

  #
  # PRIVATE
  #

  defp list_passes(_satrec, 0, _observer, _start_datetime, passes), do: passes
  defp list_passes(satrec, count, observer, start_datetime, passes) do
    new_time = start_datetime |>
      :calendar.datetime_to_gregorian_seconds
      |> Kernel.+(1) # add one second to move the next time forward a bit
      |> :calendar.gregorian_seconds_to_datetime

    this_pass = next_pass(satrec, new_time, observer)
    list_passes(satrec, count - 1, observer, this_pass.end_time, passes ++ [this_pass])
  end

  #TODO: These can be combined with list_passes above - they mostly do the same thing
  defp list_passes_until(_satrec, _observer, start_datetime, end_datetime, passes) when start_datetime >= end_datetime, do: passes
  defp list_passes_until(satrec, observer, start_datetime, end_datetime, passes) do

    new_time = start_datetime |>
      :calendar.datetime_to_gregorian_seconds
      |> Kernel.+(1) # add one second to move the next time forward a bit
      |> :calendar.gregorian_seconds_to_datetime

    this_pass = next_pass(satrec, new_time, observer)
    list_passes_until(satrec, observer, this_pass.end_time, end_datetime, passes ++ [this_pass])
  end

  defp predict_for({{_year, _month, _day}, {_hour, _min, _sec}} = input_date,
                  %Observer{longitude_rad: longitude, latitude_rad: latitude, height_km: _} = observer,
                  satellite_record) do

    gmst = Dates.utc_to_gmst(input_date)
    position_and_velocity = SGP4.propagate(satellite_record, input_date)
    position_eci = position_and_velocity.position
    #velocityEci = position_and_velocity.velocity
    position_ecf = CoordinateTransforms.eci_to_ecf(position_eci, gmst)
    geodetic = CoordinateTransforms.eci_to_geodetic(position_eci, gmst)
    look_angles = CoordinateTransforms.ecf_to_look_angles(observer, position_ecf)
    sun_position = get_position_at(input_date, latitude, longitude)
    magnitude_data = calculate_magnitude(position_eci, satellite_record.magnitude, sun_position, observer, gmst, look_angles.elevation_deg)
    footprint_radius = calculate_footprint_radius(geodetic.height)

    %{
      datetime: input_date,
      elevation_in_degrees: look_angles.elevation_deg,
      azimuth_in_degrees: look_angles.azimuth_deg,
      range: look_angles.range_sat,
      sunlit?: magnitude_data.sunlit,
      satellite_magnitude: magnitude_data.base_magnitude,
      min_wp: magnitude_data.adjusted_magnitude,
      sun_position: sun_position,
      latitude: geodetic.latitude * Constants.rad2deg,
      longitude: geodetic.longitude * Constants.rad2deg,
      height: geodetic.height,
      footprint_radius: footprint_radius
    }
  end

  defp calculate_footprint_radius(satellite_height) do
    tangent = :math.sqrt(satellite_height * (satellite_height + 2 * 6375))
    center_angle = :math.asin(tangent / (6375 + satellite_height))
    footprint_radius = 6375 * center_angle # km
    footprint_radius
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
                          %{longitude_rad: _, latitude_rad: _, height_km: _} = observer,
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
    {{yy, mm, dd}, {h, m, s}} = local_date
    Logger.debug fn -> "*** START TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local) ***" end
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
    {{yy, mm, dd}, {h, m, s}} = local_date
    Logger.debug fn -> "*** END TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local) ***" end
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  defp increment_date(date, seconds) do
    #TODO: This conversion is everywhere - put it in a helper somewhere
    date
    |> :calendar.datetime_to_gregorian_seconds
    |> Kernel.+(seconds)
    |> :calendar.gregorian_seconds_to_datetime
  end
end
