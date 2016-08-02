defmodule Satellite do
  import Satellite.DatetimeConversions
  require Logger

  def seattle_observer do
    observerGd = %{
       longitude: -122.3321 * Constants.deg2rad,
       latitude: 47.6062 * Constants.deg2rad,
       height: 0.370}
  end

  def iss_satrec do
    satellites = parse_local_tle("Visual")
    iss = satellites
         |> Enum.filter(&(&1.satellite_name == "ISS (ZARYA)"))
         |> Enum.at(0)
    iss.satrec
  end

  def save_tle_from_celestrak(tle_name) do
    body = stream_tle_from_celestrak(tle_name)
    File.write!("#{tle_name}.txt", body)
  end

  def stream_tle_from_celestrak(tle_name) do
    Application.ensure_all_started :inets
    {:ok, resp} = :httpc.request(:get, {'http://www.celestrak.com/NORAD/elements/#{tle_name}.txt', []}, [], [body_format: :binary])
    {{_, 200, 'OK'}, _headers, body} = resp
    body
  end

  def parse_local_tle(tle_name) do
    File.stream!("#{tle_name}.txt") |> parse_tle_stream
  end

  def parse_tle_stream(tle_stream) do
    tle_stream |> Stream.chunk(3) |> Enum.map(&parse_satellite/1) |> Enum.map(&to_satrec/1)
    #Logger.info "Done parsing TLE stream"
  end

  def parse_satellite(tle_lines) do
    [satellite_name | tail] = tle_lines   # line 1 - satellite name
    [tle_line_1 | tail] = tail            # line 2 - TLE line 1
    [tle_line_2 | []] = tail              # line 3 - TLE line 2

    %{
      satellite_name: String.trim(satellite_name),
      tle_line_1: String.trim(tle_line_1),
      tle_line_2: String.trim(tle_line_2)
    }
  end

  def to_satrec(satellite_map) do
    {:ok, satrec} = Twoline_To_Satrec.twoline_to_satrec(satellite_map.tle_line_1, satellite_map.tle_line_2)
    %{satellite_name: satellite_map.satellite_name, satrec: satrec}
  end

  def find_first_pass_for({{year, month, day}, {hour, min, sec}} = start_date,
                          %{longitude: _, latitude: _, height: _} = observerGd,
                          satellite_record
                          ) do

    first_prediction = predict_for(start_date, observerGd, satellite_record)
    start_of_pass = first_positive_elevation(start_date, observerGd, satellite_record, first_prediction.elevation_in_degrees, first_prediction.azimuth_in_degrees)
    end_of_pass = last_positive_elevation(start_of_pass.datetime, observerGd, satellite_record, 0.0, 0.0)

    %{start_time: start_of_pass, end_time: end_of_pass}
  end

  def first_positive_elevation(start_date, observerGd, satellite_record, elevation, azimuth) when elevation <= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"


    # increment coarsly
    new_start_date = increment_date(start_date, 60)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    first_positive_elevation(new_start_date, observerGd, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  def first_positive_elevation(start_date, observerGd, satellite_record, elevation, azimuth) do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "*** #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation} ***"

    # now back off finely
    #IO.puts ("Now backing off...")
    decrement_to_lowest_elevation(start_date, observerGd, satellite_record, elevation, azimuth)
  end

  def decrement_to_lowest_elevation(start_date, observerGd, satellite_record, elevation, azimuth) when elevation > 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"

    new_start_date = increment_date(start_date, -1)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    decrement_to_lowest_elevation(new_start_date, observerGd,  satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  def decrement_to_lowest_elevation(start_date, observerGd, satellite_record, elevation, azimuth) do
    local_date = :calendar.universal_time_to_local_time(start_date)
    {{yy, mm, dd},{h, m, s}} = local_date
    IO.puts "*** START TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation} ***"
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  def last_positive_elevation(start_date, observerGd, satellite_record, elevation, azimuth) when elevation >= 0.0 do
    #local_date = :calendar.universal_time_to_local_time(start_date)
    #{{yy, mm, dd},{h, m, s}} = local_date
    #IO.puts "#{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation}"
    # Increment until satellite goes below horizon
    new_start_date = increment_date(start_date, 1)
    prediction = predict_for(new_start_date, observerGd, satellite_record)
    last_positive_elevation(new_start_date, observerGd, satellite_record, prediction.elevation_in_degrees, prediction.azimuth_in_degrees)
  end

  def last_positive_elevation(start_date, observerGd, satellite_record, elevation, azimuth) do
    # End case - we are now at a negative elevation so return the datetime in local time
    local_date = :calendar.universal_time_to_local_time(start_date)
    {{yy, mm, dd},{h, m, s}} = local_date
    IO.puts "*** END TIME: #{yy}-#{mm}-#{dd} #{h}:#{m}:#{s}(local): elevation= #{elevation} ***"
    %{datetime: start_date, elevation: elevation, azimuth: azimuth}
  end

  def increment_date(date, seconds) do
    start_seconds = :calendar.datetime_to_gregorian_seconds(date)
    start_seconds + seconds |> :calendar.gregorian_seconds_to_datetime
  end

  def predict do
    now = :calendar.universal_time()
    now_secs = :calendar.datetime_to_gregorian_seconds(now)
    new_secs = now_secs + (3600 * 13) + (60 * 30)
    new_dt = :calendar.gregorian_seconds_to_datetime(new_secs) |> :calendar.universal_time_to_local_time
    predict_for(new_dt, seattle_observer, iss_satrec)
   end

  def predict_for({{year, month, day}, {hour, min, sec}},
                  %{longitude: _, latitude: _, height: _} = observerGd,
                  satellite_record) do

    gmst = gstime(jday(year,month,day,hour,min,sec))
    positionAndVelocity = Satellite.SGP4.propagate(satellite_record,year,month,day,hour,min,sec)
    positionEci = positionAndVelocity.position
    velocityEci = positionAndVelocity.velocity
    positionEcf = CoordinateTransforms.eci_to_ecf(positionEci, gmst)
    lookAngles = CoordinateTransforms.ecfToLookAngles(observerGd, positionEcf)
    %{
      elevation_in_degrees: lookAngles.elevation * Constants.rad2deg,
      azimuth_in_degrees: lookAngles.azimuth * Constants.rad2deg,
      range: lookAngles.rangeSat
    }
  end
end

# "visual" |> Satellite.stream_tle_from_celestrak |> String.split("\r\n") |> Satellite.parse_tle_stream
