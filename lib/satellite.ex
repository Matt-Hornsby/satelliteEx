defmodule Satellite do
  @moduledoc """
  This module provides functionality to pull satellite orbit information from
  Celestrak and to predict visible satellite passes from a specified location
  on Earth.

  ## Examples

  Satellite.predict_for({{2016, 12, 24}, {12, 12, 12}}, Satellite.seattle_observer, Satellite.iss_satrec)

  """

  import Satellite.DatetimeConversions
  import Sun.SunlightCalculations
  import Sun.SunPosition
  require Logger

  @doc """
  Returns an observerGd record for an observer in Seattle
  """
  def seattle_observer do
    %{
       longitude: -122.3321 * Constants.deg2rad,
       latitude: 47.6062 * Constants.deg2rad,
       height: 0.370}
  end

  def test do
    Logger.info "Test"
  end

  @doc """
  Returns the satellite record for ISS from the Celestrak file
  """
  def iss_satrec do
    satellites = parse_local_tle("Visual")
    iss = satellites
         |> Enum.filter(&(&1.satellite_name == "ISS (ZARYA)"))
         |> Enum.at(0)
    iss.satrec
  end

  def update_visual_TLEs_from_Celestrak, do: save_tle_from_celestrak("Visual")

  defp save_tle_from_celestrak(tle_name) do
    body = stream_tle_from_celestrak(tle_name)
    File.write!("#{tle_name}.txt", body)
  end

  defp stream_tle_from_celestrak(tle_name) do
    Application.ensure_all_started :inets
    {:ok, resp} = :httpc.request(:get, {'http://www.celestrak.com/NORAD/elements/#{tle_name}.txt', []}, [], [body_format: :binary])
    {{_, 200, 'OK'}, _headers, body} = resp
    Logger.info "#{String.length(body)} bytes read."
    body
  end

  defp parse_local_tle(tle_name) do
    File.stream!("#{tle_name}.txt") |> parse_tle_stream
  end

  defp parse_tle_stream(tle_stream) do
    tle_stream |> Stream.chunk(3) |> Enum.map(&parse_satellite/1) |> Enum.map(&to_satrec/1)
  end

  defp parse_satellite(tle_lines) do
    [satellite_name | tail] = tle_lines   # line 1 - satellite name
    [tle_line_1 | tail] = tail            # line 2 - TLE line 1
    [tle_line_2 | []] = tail              # line 3 - TLE line 2

    %{
      satellite_name: String.trim(satellite_name),
      tle_line_1: String.trim(tle_line_1),
      tle_line_2: String.trim(tle_line_2)
    }
  end

  defp to_satrec(satellite_map) do
    {:ok, satrec} = Satellite.Twoline_To_Satrec.twoline_to_satrec(satellite_map.tle_line_1, satellite_map.tle_line_2)
    %{satellite_name: satellite_map.satellite_name, satrec: satrec}
  end

  defp find_best_part_of_pass(start_of_pass, end_of_pass, observerGd, satrec, best_pass) when start_of_pass < end_of_pass do
    current_part_of_pass = predict_for(start_of_pass, observerGd, satrec)
    #IO.inspect start_of_pass
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
    find_best_part_of_pass(next_time, end_of_pass, observerGd, satrec, current_best_pass)
  end

  defp find_best_part_of_pass(_start_of_pass, _end_of_pass, _observerGd, _satrec, current_best_pass), do: current_best_pass

  def find_next_iss_pass_for_seattle, do: find_next_iss_pass(:calendar.universal_time, seattle_observer())

  def find_iss_passes(numberOfPasses, observerGd, startDateTime) when numberOfPasses > 0 do
    startPass = find_next_iss_pass(startDateTime, observerGd)
    find_iss_passes(numberOfPasses - 1, observerGd, startPass.end_time, [startPass])
  end

  def find_iss_passes(0, _observerGd, _startDateTime, passes_accumulator), do: passes_accumulator
  def find_iss_passes(numberOfPasses, observerGd, startDateTime, passes_accumulator) do

    newTime = :calendar.datetime_to_gregorian_seconds(startDateTime) + 1
              |> :calendar.gregorian_seconds_to_datetime

    thisPass = find_next_iss_pass(newTime, observerGd)

    find_iss_passes(numberOfPasses - 1, observerGd, thisPass.end_time, passes_accumulator ++ [thisPass])
  end

  def find_next_iss_pass({{_year, _month, _day}, {_hour, _min, _sec}} = start_date,
                          %{longitude: _, latitude: _, height: _} = observerGd) do

      pass = find_first_pass_for(start_date, observerGd, iss_satrec())
      start_prediction = predict_for(pass.start_of_pass.datetime, observerGd, iss_satrec())
      end_prediction = predict_for(pass.end_of_pass.datetime, observerGd, iss_satrec())

      best_part_of_pass = find_best_part_of_pass(
          pass.start_of_pass.datetime, pass.end_of_pass.datetime, observerGd, iss_satrec(), start_prediction)

      visibility = get_visibility(best_part_of_pass.sun_position.elevation_radians, best_part_of_pass.satellite_magnitude)

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


  @doc """
  Returns a human-readable classification of the satellite magnitude
  """
  def get_visibility(sun_elevation, _satellite_magnitude) when sun_elevation > 0.0, do: [:not_visible, :none]
  def get_visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 5.0, do: [:visible, :naked_eye]
  def get_visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 8.0, do: [:visible, :binoculars]
  def get_visibility(_sun_elevation, satellite_magnitude) when satellite_magnitude < 10.0, do: [:visible, :small_telescope]
  def get_visibility(_sun_elevation, _satellite_magnitude), do: [:visible, :telescope]

  def find_first_pass_for({{_year, _month, _day}, {_hour, _min, _sec}} = start_date,
                          %{longitude: _, latitude: _, height: _} = observerGd,
                          satellite_record
                          ) do

    first_prediction = predict_for(start_date, observerGd, satellite_record)
    start_of_pass = first_positive_elevation(start_date, observerGd, satellite_record, first_prediction.elevation_in_degrees, first_prediction.azimuth_in_degrees)
    end_of_pass = last_positive_elevation(start_of_pass.datetime, observerGd, satellite_record, 0.0, 0.0)

    %{start_of_pass: start_of_pass, end_of_pass: end_of_pass}
  end

  defp first_positive_elevation(start_date, observerGd, satellite_record, elevation, _azimuth) when elevation <= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"

    # increment coarsly
    new_start_date = increment_date(start_date, 60)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    first_positive_elevation(new_start_date, observerGd, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp first_positive_elevation(start_date, observerGd, satellite_record, elevation, azimuth) do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "*** #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation} ***"

    # now back off finely
    #IO.puts ("Now backing off...")
    decrement_to_lowest_elevation(start_date, observerGd, satellite_record, elevation, azimuth)
  end

  defp decrement_to_lowest_elevation(start_date, observerGd, satellite_record, elevation, _azimuth) when elevation > 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"

    new_start_date = increment_date(start_date, -1)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    decrement_to_lowest_elevation(new_start_date, observerGd,  satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp decrement_to_lowest_elevation(start_date, _observerGd, _satellite_record, elevation, azimuth) do
    local_date = :calendar.universal_time_to_local_time(start_date)
    {{yy, mm, dd},{h, m, s}} = local_date
    IO.puts "*** START TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local) ***"
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  defp last_positive_elevation(start_date, observerGd, satellite_record, elevation, _azimuth) when elevation >= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"
    # Increment until satellite goes below horizon
    new_start_date = increment_date(start_date, 1)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    last_positive_elevation(new_start_date, observerGd, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  defp last_positive_elevation(start_date, _observerGd, _satellite_record, elevation, azimuth) do
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

  def locate_current_iss_position_for_seattle do
    now = :calendar.universal_time()
    now_secs = :calendar.datetime_to_gregorian_seconds(now)
    new_secs = now_secs + (3600 * 13) + (60 * 30)
    new_dt = :calendar.gregorian_seconds_to_datetime(new_secs) |> :calendar.universal_time_to_local_time
    predict_for(new_dt, seattle_observer(), iss_satrec())
   end

  def predict_for({{year, month, day}, {hour, min, sec}} = input_date,
                  %{longitude: _, latitude: _, height: _} = observerGd,
                  satellite_record) do

    gmst = gstime(jday(year,month,day,hour,min,sec))
    positionAndVelocity = Satellite.SGP4.propagate(satellite_record,year,month,day,hour,min,sec)
    positionEci = positionAndVelocity.position
    #velocityEci = positionAndVelocity.velocity
    positionEcf = CoordinateTransforms.eci_to_ecf(positionEci, gmst)
    lookAngles = CoordinateTransforms.ecfToLookAngles(observerGd, positionEcf)
    sun_position = get_position_at(input_date, observerGd)
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
      sunlit == true -> get_base_magnitude(satmag, positionEci, sun_position, observerGd, gmst)
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
end

# "visual" |> Satellite.stream_tle_from_celestrak |> String.split("\r\n") |> Satellite.parse_tle_stream
