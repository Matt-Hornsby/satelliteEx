defmodule Satellite do
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
end

# "visual" |> Satellite.stream_tle_from_celestrak |> String.split("\r\n") |> Satellite.parse_tle_stream
